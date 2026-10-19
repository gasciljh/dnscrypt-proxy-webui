// ============================================================
// DNSCrypt Smart Filter — main.go
// Version: v1.5.0 (Global Edition)
// Last updated: 2026-10-19
// Author: gasciljh
// Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
// ============================================================
// HTTP backend for the DNSCrypt Smart Filter module.
//
// Responsibilities:
//   • Serve WebUI (9090) + Dashboard (9091)
//   • Authentication (Basic / Bearer / Cookie / Watchdog token)
//   • Rate limiting (login, Basic Auth, install)
//   • Blocklist download + rebuild (streaming I/O)
//   • SSE live updates (status, stats, resources, progress)
//   • Metrics proxy (Prometheus → JSON)
//   • Runtime info endpoint
//   • Health checks (/healthz + /readyz)
//   • Firewall lifecycle (via shell scripts)
//   • Watchdog integration
//   • Auto-backup + rotation
//   • Companion app install (4 endpoints)
//
// Build:
//   proxy/build.sh passes -buildvcs=false, -trimpath,
//   -buildid=, -mod=readonly, and injects the version via -X.
//
// ⚠️ MONITORING_UI_PORT (8080) is a cross-file constant. It
//    must stay in sync with boot-mini.sh, functions.sh,
//    customize.sh, action.sh, status.sh, service.sh, and
//    watchdog.sh.
// ============================================================

package main

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	securejoin "github.com/cyphar/filepath-securejoin"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"
)

// ============================================================
// [0] Build version variables (injected via LDFLAGS)
// ============================================================
var (
	BuildVersion = "dev"
	BuildCommit  = "unknown"
	BuildTime    = "0"
	ProjectURL   = "https://github.com/gasciljh/dnscrypt-proxy-webui"
)

// ============================================================
// [1] User-Agent
// ============================================================
// USER_AGENT is assigned once in main() via buildUserAgent().
// newHTTPRequest() falls back to defaultUserAgent() if called
// before main() — defence-in-depth for future init-time callers.
var USER_AGENT = ""

func defaultUserAgent() string {
	return "DNSCrypt-SmartFilter/" + BuildVersion
}

func buildUserAgent() string {
	return fmt.Sprintf("DNSCrypt-SmartFilter/%s (Android; +%s)",
		strings.TrimPrefix(BuildVersion, "v"), ProjectURL)
}

// ============================================================
// [2] Global paths
// ============================================================
var (
	EXEC_PATH, _   = os.Executable()
	REAL_PATH, _   = filepath.EvalSymlinks(EXEC_PATH)
	PROXYDIR       = filepath.Dir(REAL_PATH)
	MODDIR         = filepath.Dir(PROXYDIR)
	WEB_DIR        = filepath.Join(MODDIR, "web")
	WEB_FILE       = filepath.Join(WEB_DIR, "index.html")
	DASHBOARD_FILE = filepath.Join(WEB_DIR, "dashboard.html")
	OFFLINE_FILE   = filepath.Join(WEB_DIR, "offline.html")
	SW_FILE        = filepath.Join(WEB_DIR, "sw.js")
	MANIFEST_FILE  = filepath.Join(WEB_DIR, "manifest.json")

	APK_FILE         = filepath.Join(WEB_DIR, "app-debug.apk")
	APP_VERSION_FILE = filepath.Join(PROXYDIR, "app-apk.version")

	ICON_192_SVG_FILE = filepath.Join(WEB_DIR, "icon-192.svg")
	ICON_512_SVG_FILE = filepath.Join(WEB_DIR, "icon-512.svg")
	ICON_192_PNG_FILE = filepath.Join(WEB_DIR, "icon-192.png")
	ICON_512_PNG_FILE = filepath.Join(WEB_DIR, "icon-512.png")
	APPLE_TOUCH_FILE  = filepath.Join(WEB_DIR, "apple-touch-icon.png")
	FAVICON_32_FILE   = filepath.Join(WEB_DIR, "favicon-32x32.png")
	FAVICON_16_FILE   = filepath.Join(WEB_DIR, "favicon-16x16.png")
	FAVICON_ICO_FILE  = filepath.Join(WEB_DIR, "favicon.ico")

	CONF_FILE          = filepath.Join(PROXYDIR, "webui.conf")
	BIN                = filepath.Join(PROXYDIR, "dnscrypt-proxy")
	CONF               = filepath.Join(PROXYDIR, "dnscrypt-proxy.toml")
	SELECTED_FILE      = filepath.Join(PROXYDIR, "selected_profile.txt")
	BLOCKLIST_FILE     = filepath.Join(PROXYDIR, "blocklist.txt")
	RAW_BLOCKLIST_FILE = filepath.Join(PROXYDIR, "blocklist.raw")
	ALLOWLIST_FILE     = filepath.Join(PROXYDIR, "allowlist.txt")
	DENYLIST_FILE      = filepath.Join(PROXYDIR, "denylist.txt")
	LOG_FILE           = "/data/local/tmp/dnscrypt_main.log"
	LOGS_DIR           = "/data/local/tmp"
	MODULES_DIR        = "/data/adb/modules"

	RUN_DIR = filepath.Join(PROXYDIR, "run")

	STATUS_FILE   string
	PID_FILE      string
	PROGRESS_FILE string

	PERSISTENT_BACKUP   = "/sdcard/dnscrypt-webui-backup"
	PENDING_NOTIFY_FILE = "/sdcard/dnscrypt-webui-backup/.pending_notification"
	LAST_STABLE_FILE    = "/sdcard/dnscrypt-webui-backup/.last_stable"

	WATCHDOG_TOKEN_FILE string
)

// ============================================================
// [3] Configuration constants
// ============================================================
const (
	DOWNLOAD_TIMEOUT       = 300
	DOWNLOAD_RETRIES       = 3
	MAX_LOG_SIZE           = 1024 * 1024
	MAX_LOG_MSG_SIZE       = 4096
	MAX_BLOCKLIST_SIZE     = 50 * 1024 * 1024
	HTTP_READ_TIMEOUT      = 5 * time.Second
	HTTP_IDLE_TIMEOUT      = 120 * time.Second
	MAX_LOG_LINES          = 300
	MAX_OLD_MODULES_SHOW   = 50
	MAX_GZ_FILES           = 5
	SERVICE_START_TIMEOUT  = 45 * time.Second
	MIN_BLOCKLIST_SIZE     = 100 * 1024
	SSE_KEEPALIVE_INTERVAL = 15 * time.Second
	SSE_WRITE_TIMEOUT      = 30 * time.Second

	// HTTP_WRITE_TIMEOUT bounds the entire response-writing phase
	// of every HTTP request, including the install endpoint whose
	// server-side budget is INSTALL_TIMEOUT (90 s). It MUST be
	// strictly greater than INSTALL_TIMEOUT + serialization +
	// network drain, otherwise the client sees a connection reset
	// while the server-side install has actually completed.
	HTTP_WRITE_TIMEOUT = 150 * time.Second

	SESSION_TTL          = 24 * time.Hour
	SESSION_COOKIE_NAME  = "dnscrypt_session"
	MAX_LOGIN_ATTEMPTS   = 5
	LOGIN_LOCKOUT_PERIOD = 15 * time.Minute

	LOGIN_ATTEMPT_STALE_PERIOD = 1 * time.Hour

	MAX_STDERR_CAPTURE = 2048

	MAX_POST_BODY_SIZE = 5 * 1024 * 1024
	STATUS_CACHE_TTL   = 2 * time.Second
	SESSION_GC_PERIOD  = 30 * time.Minute

	RUN_DIR_USABLE_CACHE_TTL = 30 * time.Second

	PORT_CACHE_TTL = 5 * time.Second

	// Short timeout for TCP/UDP port probes. Probes run on the
	// SSE and stats paths and can fire several times per second.
	PORT_PROBE_TIMEOUT = 3 * time.Second

	AUTH_CACHE_TTL = 60 * time.Second

	LAST_UPDATE_CACHE_TTL = 5 * time.Second

	// TTL for webui.conf port reads. Both getWebUIPort() and
	// getDashboardPort() route through readConfPortCached().
	CONF_PORT_CACHE_TTL = 30 * time.Second

	MEMORY_LIMIT_LIGHT    = 80 * 1024 * 1024
	MEMORY_LIMIT_NORMAL   = 100 * 1024 * 1024
	MEMORY_LIMIT_PRO      = 120 * 1024 * 1024
	MEMORY_LIMIT_PROPLUS  = 160 * 1024 * 1024
	MEMORY_LIMIT_ULTIMATE = 220 * 1024 * 1024
	MEMORY_LIMIT_DEFAULT  = 80 * 1024 * 1024

	DENY_MARKER_START  = "# === CUSTOM_DENYLIST_START ==="
	DENY_MARKER_END    = "# === CUSTOM_DENYLIST_END ==="
	LEGACY_DENY_MARKER = "# === Custom Denylist ==="

	STREAM_WRITE_BUFFER = 64 * 1024
	STREAM_READ_BUFFER  = 64 * 1024
	STREAM_MAX_LINE     = 1024 * 1024

	LOG_MAX_READ_BYTES     = 500 * 1024
	LOG_MAX_DOWNLOAD_BYTES = 100 * 1024 * 1024

	MONITORING_UI_PORT = "8080"

	AUTO_BACKUP_TIMEOUT = 15 * time.Second

	WATCHDOG_TOKEN_HEADER = "X-Watchdog-Token"

	// Max bytes for the upstream metrics response. Bounds memory
	// when monitoring_ui returns an unexpectedly large body.
	METRICS_MAX_BODY = 2 * 1024 * 1024
)

// ============================================================
// [3b] Companion app install constants
// ============================================================
const (
	INSTALL_SCRIPT_REL        = "install_app.sh"
	INSTALL_TIMEOUT           = 90 * time.Second
	INSTALL_TOKEN_TTL         = 60 * time.Second
	MAX_INSTALL_ATTEMPTS      = 5
	INSTALL_LOCKOUT_PERIOD    = 15 * time.Minute
	COMPANION_STATE_CACHE_TTL = 30 * time.Second
)

// ============================================================
// [4] Types
// ============================================================
type Profile struct {
	Name string
	URL  string
}

type OldModuleInfo struct {
	Path     string `json:"path"`
	Version  string `json:"version"`
	Disabled bool   `json:"disabled"`
	Name     string `json:"name"`
	ID       string `json:"id"`
}

type Session struct {
	Username  string
	CreatedAt time.Time
	ExpiresAt time.Time
}

type LoginAttempt struct {
	Count       int
	LastAttempt time.Time
	LockedUntil time.Time
}

type InstallToken struct {
	Value     string
	ExpiresAt time.Time
	Used      bool
}

type InstallAttempt struct {
	Count       int
	LastAttempt time.Time
	LockedUntil time.Time
}

type ProgressWriter struct {
	writer      io.Writer
	total       int64
	downloaded  int64
	lastPercent int
	onProgress  func(int, string)
}

func (pw *ProgressWriter) Write(p []byte) (int, error) {
	n, err := pw.writer.Write(p)
	if err == nil {
		pw.downloaded += int64(n)
		percent := 10
		if pw.total > 0 {
			percent = 10 + int((float64(pw.downloaded)/float64(pw.total))*70)
		}
		if percent > 80 {
			percent = 80
		}
		if percent != pw.lastPercent && percent%5 == 0 {
			pw.lastPercent = percent
			mb := float64(pw.downloaded) / (1024 * 1024)
			pw.onProgress(percent, fmt.Sprintf("Downloading... (%.1f MB)", mb))
		}
	}
	return n, err
}

type LogFileInfo struct {
	Name      string `json:"name"`
	Size      int64  `json:"size"`
	MTime     int64  `json:"mtime"`
	Type      string `json:"type"`
	Extension string `json:"extension"`
}

// limitedBuffer caps captured stderr at `max` bytes. Prevents
// unbounded heap growth when a misbehaving shell command emits
// long diagnostics.
type limitedBuffer struct {
	buf bytes.Buffer
	max int
}

func (lb *limitedBuffer) Write(p []byte) (int, error) {
	if lb.max <= 0 {
		return len(p), nil
	}
	if lb.buf.Len() >= lb.max {
		return len(p), nil
	}
	room := lb.max - lb.buf.Len()
	if len(p) > room {
		lb.buf.Write(p[:room])
		return len(p), nil
	}
	return lb.buf.Write(p)
}

func (lb *limitedBuffer) String() string { return lb.buf.String() }
func (lb *limitedBuffer) Len() int       { return lb.buf.Len() }

// httpServerLogWriter routes net/http's internal logger into our
// leveled logger.
type httpServerLogWriter struct{}

func (w *httpServerLogWriter) Write(p []byte) (int, error) {
	msg := strings.TrimSpace(string(p))
	if msg != "" {
		logWithLevel("warn", "HTTP server: "+msg)
	}
	return len(p), nil
}

type portCacheEntry struct {
	open bool
	time time.Time
}

// ============================================================
// [5] Rules state
// ============================================================
type rulesStateSnapshot struct {
	AllowlistHash string
	DenylistHash  string
}

var (
	rulesStateMu sync.RWMutex
	currentRules rulesStateSnapshot
	rebuildMu    sync.Mutex
)

func getRulesState() rulesStateSnapshot {
	rulesStateMu.RLock()
	defer rulesStateMu.RUnlock()
	return currentRules
}

func contentHash(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func fileHash(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return contentHash(data)
}

func initRulesState() {
	state := rulesStateSnapshot{
		AllowlistHash: fileHash(ALLOWLIST_FILE),
		DenylistHash:  fileHash(DENYLIST_FILE),
	}
	rulesStateMu.Lock()
	currentRules = state
	rulesStateMu.Unlock()
}

// ============================================================
// [6] HTTP client
// ============================================================
// The resolver pins bootstrap DNS to 8.8.8.8 (TCP first, UDP
// fallback) so a broken local resolver cannot break the
// download path.
var (
	downloadClientMu sync.Mutex
	downloadClient   *http.Client
)

func createDownloadClient() *http.Client {
	dialer := &net.Dialer{
		Timeout:   10 * time.Second,
		KeepAlive: 30 * time.Second,
	}
	resolver := &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			conn, err := (&net.Dialer{Timeout: 5 * time.Second}).DialContext(ctx, "tcp", "8.8.8.8:53")
			if err == nil {
				return conn, nil
			}
			return (&net.Dialer{Timeout: 5 * time.Second}).DialContext(ctx, "udp", "8.8.8.8:53")
		},
	}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			dialer.Resolver = resolver
			return dialer.DialContext(ctx, network, addr)
		},
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          5,
		MaxIdleConnsPerHost:   2,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		ResponseHeaderTimeout: 30 * time.Second,
	}
	return &http.Client{
		Transport: transport,
		Timeout:   DOWNLOAD_TIMEOUT * time.Second,
	}
}

func getDownloadClient() *http.Client {
	downloadClientMu.Lock()
	defer downloadClientMu.Unlock()
	if downloadClient != nil {
		return downloadClient
	}
	downloadClient = createDownloadClient()
	return downloadClient
}

func resetDownloadClient() {
	downloadClientMu.Lock()
	defer downloadClientMu.Unlock()
	if downloadClient != nil {
		if tr, ok := downloadClient.Transport.(*http.Transport); ok {
			tr.CloseIdleConnections()
		}
		downloadClient = nil
	}
}

// ============================================================
// [7] run/ directory initialization
// ============================================================
// isRunDirUsable performs a live write test on RUN_DIR and caches
// the result for RUN_DIR_USABLE_CACHE_TTL (30 s). The test —
// MkdirAll + Chmod + a small WriteFile — matches the effective
// write-ability semantics of boot-mini.sh:get_run_dir()'s `-w`
// check while being strictly stronger: it catches SELinux
// contexts that allow the directory to exist and be readable but
// reject file creation.
var (
	runDirUsableCached bool
	runDirUsableTime   time.Time
	runDirUsableMutex  sync.Mutex
)

func isRunDirUsable() bool {
	runDirUsableMutex.Lock()
	defer runDirUsableMutex.Unlock()

	if !runDirUsableTime.IsZero() && time.Since(runDirUsableTime) < RUN_DIR_USABLE_CACHE_TTL {
		return runDirUsableCached
	}

	result := func() bool {
		if err := os.MkdirAll(RUN_DIR, 0700); err != nil {
			return false
		}
		_ = os.Chmod(RUN_DIR, 0700)

		testFile := filepath.Join(RUN_DIR, ".write_test")
		if err := os.WriteFile(testFile, []byte("ok"), 0600); err != nil {
			return false
		}
		os.Remove(testFile)
		return true
	}()

	runDirUsableCached = result
	runDirUsableTime = time.Now()
	return result
}

func initPaths() {
	if isRunDirUsable() {
		STATUS_FILE = filepath.Join(RUN_DIR, "dnscrypt.status")
		PID_FILE = filepath.Join(RUN_DIR, "dnscrypt.pid")
		PROGRESS_FILE = filepath.Join(RUN_DIR, "update_progress.txt")
		WATCHDOG_TOKEN_FILE = filepath.Join(RUN_DIR, ".watchdog_token")
	} else {
		STATUS_FILE = "/data/local/tmp/dnscrypt.status"
		PID_FILE = "/data/local/tmp/dnscrypt.pid"
		PROGRESS_FILE = "/data/local/tmp/update_progress.txt"
		WATCHDOG_TOKEN_FILE = "/data/local/tmp/.watchdog_token"
	}
}

func getActiveRunDir() string {
	return filepath.Dir(STATUS_FILE)
}

// ============================================================
// [8] Global variables
// ============================================================
var (
	updatingMu sync.Mutex
	isUpdating bool
	logMutex   sync.Mutex

	// Entries-count cache. Key is (size, mtime, inode). The
	// inode field closes a staleness window on filesystems
	// whose mtime resolution is coarser than the write rate.
	countCacheMu sync.Mutex
	cachedCount  int
	lastSize     int64
	lastModTime  time.Time
	lastInode    uint64

	lastUpdateCache string
	lastUpdateTime  time.Time
	lastUpdateMu    sync.Mutex

	profiles = map[string]Profile{
		"light":    {"HaGeZi Light", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/light.txt"},
		"normal":   {"HaGeZi Normal", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt"},
		"pro":      {"HaGeZi PRO", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"},
		"proplus":  {"HaGeZi PRO++", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt"},
		"ultimate": {"HaGeZi Ultimate", "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/ultimate.txt"},
	}

	oldModulesCache []OldModuleInfo
	oldModulesTime  time.Time
	oldModulesMutex sync.Mutex
	serverPort      = "9090"

	serverBindAddr = "127.0.0.1"

	sseClients = make(map[chan string]bool)
	sseMutex   sync.Mutex

	statsCache string
	statsTime  time.Time
	statsMutex sync.Mutex

	resourceCache string
	resourceTime  time.Time
	resourceMutex sync.Mutex

	portCacheMu  sync.Mutex
	portCacheMap = make(map[int]portCacheEntry)

	cachedStatusVal  string
	cachedStatusTime time.Time
	statusCacheMutex sync.Mutex

	serviceMutex sync.Mutex

	sessions   = make(map[string]*Session)
	sessionsMu sync.RWMutex

	loginAttempts   = make(map[string]*LoginAttempt)
	loginAttemptsMu sync.Mutex

	dashboardProxyClient = &http.Client{Timeout: 5 * time.Second}

	currentLogLevel = "info"

	systemShellOnce sync.Once
	systemShellPath string

	funcScriptOnce sync.Once
	funcScriptPath string

	authCacheMu   sync.RWMutex
	authCacheUser string
	authCachePass string
	authCacheTime time.Time

	memLimitMu      sync.Mutex
	currentMemLimit int64  = MEMORY_LIMIT_DEFAULT
	currentProfile  string = "pro"

	backupMu sync.Mutex

	watchdogTokMu    sync.RWMutex
	watchdogTokValue string
	watchdogTokTime  time.Time

	// webui.conf port cache. Two INDEPENDENT slots — each has
	// its own value AND its own timestamp. 30 s TTL is short
	// enough for any human edit cycle.
	portConfMu       sync.RWMutex
	cachedWebPort    string
	cachedWebPortAt  time.Time
	cachedDashPort   string
	cachedDashPortAt time.Time
)

// ============================================================
// [8b] Companion app install state
// ============================================================
var (
	installTokens   = make(map[string]*InstallToken)
	installTokensMu sync.Mutex

	installAttempts   = make(map[string]*InstallAttempt)
	installAttemptsMu sync.Mutex

	companionStateCache string
	companionStateTime  time.Time
	companionStateMutex sync.Mutex
)

// ============================================================
// [9] Read webui.conf settings
// ============================================================

// readConfValue returns the value of key from webui.conf, or
// defaultValue if the file, key, or value is missing.
//
// Named return + pre-initialization ensures defaultValue is
// returned even if a panic occurs mid-read. A bare
// `defer recover()` would return the zero value "" instead,
// which would cascade into empty port strings and break
// net.JoinHostPort callers.
func readConfValue(key, defaultValue string) (result string) {
	result = defaultValue
	defer func() { recover() }()

	data, err := os.ReadFile(CONF_FILE)
	if err != nil {
		return
	}

	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "#") || line == "" {
			continue
		}
		if strings.HasPrefix(line, key+"=") {
			val := strings.TrimSpace(strings.TrimPrefix(line, key+"="))
			if idx := strings.Index(val, " #"); idx > 0 {
				val = strings.TrimSpace(val[:idx])
			}
			if val != "" {
				result = val
				return
			}
		}
	}
	return
}

// readConfPort reads a port from webui.conf and validates its
// range. Named return + pre-initialization mirrors
// readConfValue: on panic, defaultPort is returned rather than
// the zero value "".
func readConfPort(key, defaultPort string) (result string) {
	result = defaultPort
	defer func() { recover() }()
	val := readConfValue(key, defaultPort)
	n, err := strconv.Atoi(val)
	if err != nil || n < 1 || n > 65535 {
		return
	}
	result = val
	return
}

// readConfPortCached wraps readConfPort with a 30-second TTL
// cache. The two slots ("webui" and "dashboard") are fully
// INDEPENDENT — each has its own value AND its own timestamp.
func readConfPortCached(key, defaultPort, which string) string {
	portConfMu.RLock()
	var cached string
	var cachedAt time.Time
	switch which {
	case "webui":
		cached = cachedWebPort
		cachedAt = cachedWebPortAt
	case "dashboard":
		cached = cachedDashPort
		cachedAt = cachedDashPortAt
	}
	fresh := !cachedAt.IsZero() && time.Since(cachedAt) < CONF_PORT_CACHE_TTL
	portConfMu.RUnlock()

	if fresh && cached != "" {
		return cached
	}

	val := readConfPort(key, defaultPort)

	portConfMu.Lock()
	switch which {
	case "webui":
		cachedWebPort = val
		cachedWebPortAt = time.Now()
	case "dashboard":
		cachedDashPort = val
		cachedDashPortAt = time.Now()
	}
	portConfMu.Unlock()

	return val
}

func getWebUIPort() string {
	return readConfPortCached("PORT", "9090", "webui")
}

func getDashboardPort() string {
	return readConfPortCached("DASHBOARD_PORT", "9091", "dashboard")
}

// ============================================================
// [9b] BIND_ADDR
// ============================================================
func getBindAddr() string {
	addr := strings.TrimSpace(readConfValue("BIND_ADDR", "127.0.0.1"))

	if addr == "localhost" {
		return "127.0.0.1"
	}

	if net.ParseIP(addr) == nil {
		if addr != "" {
			logWithLevel("warn", "⚠️ Invalid BIND_ADDR: '"+addr+"' — using 127.0.0.1")
		}
		return "127.0.0.1"
	}

	return addr
}

func isExposedBind(addr string) bool {
	if addr == "" {
		return false
	}
	switch addr {
	case "127.0.0.1", "::1", "localhost":
		return false
	}
	return true
}

// ============================================================
// [9c] isSecureCookie
// ============================================================
func isSecureCookie() bool {
	switch serverBindAddr {
	case "127.0.0.1", "::1", "localhost":
		return true
	}
	return false
}

func loadLogLevel() string {
	val := readConfValue("LOG_LEVEL", "info")
	switch val {
	case "error", "warn", "info", "debug":
		return val
	default:
		return "info"
	}
}

// ============================================================
// [9d] Memory limit helpers
// ============================================================
func readSelectedProfile() string {
	data, err := os.ReadFile(SELECTED_FILE)
	if err != nil {
		return "pro"
	}
	key := strings.TrimSpace(string(data))
	if key == "" {
		return "pro"
	}
	if _, ok := profiles[key]; !ok {
		return "pro"
	}
	return key
}

func memoryLimitForProfile(key string) int64 {
	switch strings.ToLower(strings.TrimSpace(key)) {
	case "light":
		return MEMORY_LIMIT_LIGHT
	case "normal":
		return MEMORY_LIMIT_NORMAL
	case "pro":
		return MEMORY_LIMIT_PRO
	case "proplus":
		return MEMORY_LIMIT_PROPLUS
	case "ultimate":
		return MEMORY_LIMIT_ULTIMATE
	default:
		return MEMORY_LIMIT_DEFAULT
	}
}

// applyMemoryLimit sets the Go runtime soft memory limit based
// on the active profile. No-op when the limit and profile are
// unchanged.
func applyMemoryLimit(key string) {
	memLimitMu.Lock()
	defer memLimitMu.Unlock()

	limit := memoryLimitForProfile(key)
	if limit == currentMemLimit && key == currentProfile {
		return
	}

	prevLimit := currentMemLimit
	_ = debug.SetMemoryLimit(limit)
	currentMemLimit = limit
	currentProfile = key

	logWithLevel("info", fmt.Sprintf(
		"memory limit adjusted: %d MB → %d MB (profile=%s)",
		prevLimit/(1024*1024), limit/(1024*1024), key))
}

// ============================================================
// [9e] Companion app version reader
// ============================================================
// Reads proxy/app-apk.version (the SSOT for the companion APK
// version). Exposed via runtime_info so web/index.html can
// build the direct GitHub APK download URL without hardcoding
// the version.
//
// Cached once per process — the file only changes on module
// reinstall, which restarts main.go.
var (
	appVersionOnce sync.Once
	appVersionVal  string
)

func readAppVersion() string {
	appVersionOnce.Do(func() {
		data, err := os.ReadFile(APP_VERSION_FILE)
		if err != nil {
			appVersionVal = "unknown"
			return
		}
		v := strings.TrimSpace(string(data))
		if v == "" {
			v = "unknown"
		}
		appVersionVal = v
	})
	return appVersionVal
}

// ============================================================
// [10] Logging — three-layer split
// ============================================================
// The logger is split into three layers to eliminate a
// reentrancy hazard: sync.Mutex is not reentrant in Go, so
// calling the public logger from inside the rotation branch
// (which holds logMutex) would deadlock.
//
//   1. logWithLevel — public. Applies the level filter,
//                     acquires logMutex, delegates to logLocked.
//   2. logLocked    — MUST be called with logMutex held.
//                     Rotation + writeLocked.
//   3. writeLocked  — MUST be called with logMutex held.
//                     Writes a single formatted line.

func logWithLevel(level, msg string) {
	if !shouldLog(level) {
		return
	}

	logMutex.Lock()
	defer logMutex.Unlock()

	logLocked(level, msg)
}

// shouldLog reports whether a message at the given level passes
// the current filter. Safe to call WITHOUT holding logMutex —
// currentLogLevel is written exactly once in main() before any
// logging goroutine is started.
func shouldLog(level string) bool {
	levelMap := map[string]int{"error": 0, "warn": 1, "info": 2, "debug": 3}
	return levelMap[level] <= levelMap[currentLogLevel]
}

// logLocked performs the actual logging. MUST be called with
// logMutex held. Rotates the log when it exceeds MAX_LOG_SIZE.
func logLocked(level, msg string) {
	defer func() { recover() }()

	if len(msg) > MAX_LOG_MSG_SIZE {
		msg = msg[:MAX_LOG_MSG_SIZE] + "...[truncated]"
	}

	if fi, err := os.Stat(LOG_FILE); err == nil && fi.Size() > MAX_LOG_SIZE {
		timestampFile := fmt.Sprintf("%s.%d.old", LOG_FILE, time.Now().UnixNano())
		if err := os.Rename(LOG_FILE, timestampFile); err != nil {
			// We hold logMutex. Emit the warning via
			// writeLocked — re-entering logWithLevel would
			// deadlock.
			writeLocked("warn", "⚠️ log rotation: rename failed: "+err.Error())
		} else {
			go compressLogFile(timestampFile)
		}
	}

	writeLocked(level, msg)
}

// writeLocked writes a single formatted line to LOG_FILE. MUST
// be called with logMutex held.
//
// If the log file cannot be opened, the message is written to
// stderr instead — a silent failure would make debugging
// impossible.
func writeLocked(level, msg string) {
	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		short := msg
		if len(short) > 200 {
			short = short[:200] + "..."
		}
		fmt.Fprintf(os.Stderr,
			"[%s] [LOG-WRITE-FAIL] %s (open error: %v)\n",
			time.Now().UTC().Format(time.RFC3339), short, err)
		return
	}
	defer f.Close()

	timestamp := time.Now().UTC().Format(time.RFC3339)
	prefix := ""
	switch level {
	case "error":
		prefix = "[ERROR] "
	case "warn":
		prefix = "[WARN]  "
	case "debug":
		prefix = "[DEBUG] "
	}
	fmt.Fprintf(f, "[%s] %s%s\n", timestamp, prefix, msg)
}

func logEvent(msg string) { logWithLevel("info", msg) }

// sanitizeLogText removes characters that could corrupt a
// single-line log entry. Defends against log injection when the
// input comes from a request field (e.g. the login username).
//
// `\n` and `\r` become a single space; other C0 controls are
// dropped. Length is capped at 128 chars.
func sanitizeLogText(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	for _, r := range s {
		switch {
		case r == '\n' || r == '\r' || r == '\t':
			b.WriteByte(' ')
		case r < 0x20:
			// drop other C0 controls
		default:
			b.WriteRune(r)
		}
		if b.Len() >= 128 {
			break
		}
	}
	return b.String()
}

// compressLogFile gzips a rotated log and prunes old archives.
// Runs in a goroutine — failures are silent (best-effort).
func compressLogFile(filePath string) {
	defer func() { recover() }()
	src, err := os.Open(filePath)
	if err != nil {
		return
	}
	defer src.Close()

	gzPath := filePath + ".gz"
	dest, err := os.OpenFile(gzPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		logWithLevel("warn", "⚠️ log compress: cannot create "+gzPath+": "+err.Error())
		return
	}
	defer dest.Close()

	gzWriter := gzip.NewWriter(dest)
	if _, err := io.Copy(gzWriter, src); err != nil {
		gzWriter.Close()
		os.Remove(gzPath)
		return
	}
	if err := gzWriter.Close(); err != nil {
		os.Remove(gzPath)
		return
	}
	os.Remove(filePath)
	cleanupOldGz(filepath.Dir(filePath))
}

// cleanupOldGz keeps at most MAX_GZ_FILES rotated archives.
// The glob is scoped to our own archives so unrelated .gz
// files in the same directory are never touched.
func cleanupOldGz(dir string) {
	defer func() { recover() }()
	pattern := filepath.Join(dir, filepath.Base(LOG_FILE)+".*.gz")
	files, err := filepath.Glob(pattern)
	if err != nil || len(files) <= MAX_GZ_FILES {
		return
	}
	sort.Strings(files)
	for i := 0; i < len(files)-MAX_GZ_FILES; i++ {
		os.Remove(files[i])
	}
}

// ============================================================
// [11] Atomic writes
// ============================================================
func atomicWriteFile(filename string, data []byte, perm os.FileMode) error {
	dir := filepath.Dir(filename)

	tmp, err := os.CreateTemp(dir, filepath.Base(filename)+".tmp_*")
	if err != nil {
		return fmt.Errorf("create tmp: %w", err)
	}
	tmpName := tmp.Name()

	success := false
	defer func() {
		if !success {
			tmp.Close()
			os.Remove(tmpName)
		}
	}()

	if _, err := tmp.Write(data); err != nil {
		return fmt.Errorf("write tmp: %w", err)
	}

	if err := tmp.Sync(); err != nil {
		return fmt.Errorf("sync tmp: %w", err)
	}

	if err := tmp.Chmod(perm); err != nil {
		return fmt.Errorf("chmod tmp: %w", err)
	}

	if err := tmp.Close(); err != nil {
		return fmt.Errorf("close tmp: %w", err)
	}

	if err := os.Rename(tmpName, filename); err != nil {
		return fmt.Errorf("rename tmp: %w", err)
	}

	syncParentDir(dir)

	success = true
	return nil
}

// atomicWriteStream is the streaming variant of atomicWriteFile.
// The caller supplies a callback that writes to an io.Writer;
// the file is renamed into place only after the callback and
// all sync/flush steps succeed.
func atomicWriteStream(filename string, perm os.FileMode, writeFn func(io.Writer) error) error {
	dir := filepath.Dir(filename)

	f, err := os.CreateTemp(dir, filepath.Base(filename)+".tmp_*")
	if err != nil {
		return fmt.Errorf("create tmp: %w", err)
	}
	tmpName := f.Name()

	success := false
	defer func() {
		if !success {
			f.Close()
			os.Remove(tmpName)
		}
	}()

	bw := bufio.NewWriterSize(f, STREAM_WRITE_BUFFER)

	if err := writeFn(bw); err != nil {
		bw.Flush()
		return fmt.Errorf("write callback: %w", err)
	}

	if err := bw.Flush(); err != nil {
		return fmt.Errorf("flush: %w", err)
	}

	if err := f.Sync(); err != nil {
		return fmt.Errorf("sync: %w", err)
	}

	if err := f.Chmod(perm); err != nil {
		return fmt.Errorf("chmod tmp: %w", err)
	}

	if err := f.Close(); err != nil {
		return fmt.Errorf("close: %w", err)
	}

	if err := os.Rename(tmpName, filename); err != nil {
		return fmt.Errorf("rename tmp: %w", err)
	}

	syncParentDir(dir)

	success = true
	return nil
}

// syncParentDir fsyncs the directory containing `dir` so the
// rename's directory-entry update survives a power loss on a
// non-journaled filesystem. Best-effort: a failure is logged at
// debug level and does not abort the caller.
func syncParentDir(dir string) {
	d, err := os.Open(dir)
	if err != nil {
		logWithLevel("debug", "syncParentDir: open "+dir+": "+err.Error())
		return
	}
	defer d.Close()
	if err := d.Sync(); err != nil {
		logWithLevel("debug", "syncParentDir: sync "+dir+": "+err.Error())
	}
}

// ============================================================
// [12] Shell command execution
// ============================================================
// shellEnv returns the environment for shell subprocesses.
// MODDIR and PROXYDIR are passed explicitly so child scripts
// (functions.sh, install_app.sh) resolve paths correctly even
// when invoked via /system/bin/sh — where $0 would otherwise
// resolve to a system path (e.g. /system/bin/sh), causing
// functions.sh to search for boot-mini.sh under /system/bin
// and fail.
//
// This is defense-in-depth: functions.sh [1] and boot-mini.sh
// [1] already reject system paths via their own case statements.
// Passing the environment makes the intent explicit and fixes
// any future script that uses `[ -z "${MODDIR:-}" ]` without
// the system-path rejection.
//
// os.Environ() is preserved (rather than replaced) so that
// PATH, HOME, TMPDIR, and every other inherited variable
// remain available to the child — shell utilities like
// `timeout`, `pgrep`, `iptables`, `settings`, and `getprop`
// all depend on PATH being set.
func shellEnv() []string {
	return append(os.Environ(),
		"MODDIR="+MODDIR,
		"PROXYDIR="+PROXYDIR,
	)
}

func getSystemShell() string {
	systemShellOnce.Do(func() {
		candidates := []string{"/system/bin/sh", "/bin/sh", "/usr/bin/sh"}
		for _, c := range candidates {
			if _, err := os.Stat(c); err == nil {
				systemShellPath = c
				return
			}
		}
		systemShellPath = "sh"
	})
	return systemShellPath
}

// getFunctionsScript returns the absolute path to functions.sh.
// Prefers $MODDIR/functions.sh, falls back to $PROXYDIR.
func getFunctionsScript() string {
	funcScriptOnce.Do(func() {
		candidates := []string{
			filepath.Join(MODDIR, "functions.sh"),
			filepath.Join(PROXYDIR, "functions.sh"),
		}
		for _, c := range candidates {
			if _, err := os.Stat(c); err == nil {
				funcScriptPath = c
				return
			}
		}
		funcScriptPath = filepath.Join(MODDIR, "functions.sh")
	})
	return funcScriptPath
}

// shellQuote wraps s in single quotes when it contains any
// shell metacharacter. Safe for POSIX sh.
func shellQuote(s string) string {
	for _, r := range s {
		if r == ' ' || r == '"' || r == '\'' || r == '$' || r == '`' ||
			r == '\\' || r == '!' || r == '&' || r == '|' || r == ';' ||
			r == '(' || r == ')' || r == '<' || r == '>' || r == '*' ||
			r == '?' || r == '[' || r == ']' || r == '#' || r == '~' ||
			r == '{' || r == '}' || r == '\n' || r == '\t' {
			return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
		}
	}
	return s
}

// runShell runs a shell command with a conservative default
// timeout (15 s). Callers that need a different budget use
// runShellWithTimeout directly.
func runShell(cmd string) error {
	return runShellWithTimeout(cmd, 15*time.Second)
}

// runShellWithTimeout runs a shell command with a caller-provided
// timeout. Captures up to MAX_STDERR_CAPTURE bytes of stderr.
// A timeout is logged with a "(timeout)" marker.
func runShellWithTimeout(cmd string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	command := exec.CommandContext(ctx, getSystemShell(), "-c", cmd)
	command.Env = shellEnv()
	command.Stdout = io.Discard

	errBuf := &limitedBuffer{max: MAX_STDERR_CAPTURE}
	command.Stderr = errBuf

	start := time.Now()
	err := command.Run()
	elapsed := time.Since(start)

	if err != nil {
		errOutput := strings.TrimSpace(errBuf.String())
		timeoutMarker := ""
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			timeoutMarker = " (timeout)"
		}
		if errOutput != "" {
			logWithLevel("warn", fmt.Sprintf(
				"⚠️ Shell%s (timeout=%v, took=%v) failed: %s (%v) stderr: %s",
				timeoutMarker, timeout, elapsed, cmd, err, errOutput))
		} else {
			logWithLevel("warn", fmt.Sprintf(
				"⚠️ Shell%s (timeout=%v, took=%v) failed: %s (%v)",
				timeoutMarker, timeout, elapsed, cmd, err))
		}
	}
	return err
}

// ============================================================
// [13] HTTP request helper
// ============================================================
func newHTTPRequest(ctx context.Context, method, url string, body io.Reader) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, method, url, body)
	if err != nil {
		return nil, err
	}
	ua := USER_AGENT
	if ua == "" {
		ua = defaultUserAgent()
	}
	req.Header.Set("User-Agent", ua)
	req.Header.Set("Accept", "text/plain, */*;q=0.1")
	return req, nil
}

// ============================================================
// [14] SSE
// ============================================================
func broadcastEvent(event string, data string) {
	sseMutex.Lock()
	defer sseMutex.Unlock()
	msg := fmt.Sprintf("event: %s\ndata: %s\n\n", event, data)
	for ch := range sseClients {
		select {
		case ch <- msg:
		default:
		}
	}
}

// sseHandler streams Server-Sent Events to a single client.
//
// Ordering note: the initial snapshots (status/stats/resources)
// are pushed into the channel BEFORE the channel is registered
// in sseClients. A concurrent broadcastEvent could otherwise
// fill the 100-slot buffer before the reader loop is reached,
// and the blocking send would hang the connection forever
// (defer cleanup would never run, and the client would stay in
// sseClients until process restart).
func sseHandler(w http.ResponseWriter, r *http.Request) {
	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	rc := http.NewResponseController(w)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))
	if err := rc.Flush(); err != nil {
		return
	}

	ch := make(chan string, 100)

	ch <- fmt.Sprintf("event: status\ndata: %s\n\n", getStatus())
	ch <- fmt.Sprintf("event: stats\ndata: {\"blocked_today\":\"%s\"}\n\n", getBlockedStats())
	ch <- fmt.Sprintf("event: resources\ndata: {\"ram\":\"%s\"}\n\n", getResourceUsage())

	sseMutex.Lock()
	sseClients[ch] = true
	sseMutex.Unlock()

	defer func() {
		sseMutex.Lock()
		delete(sseClients, ch)
		close(ch)
		sseMutex.Unlock()
	}()

	ticker := time.NewTicker(SSE_KEEPALIVE_INTERVAL)
	defer ticker.Stop()

	for {
		select {
		case msg := <-ch:
			_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))
			if _, err := fmt.Fprint(w, msg); err != nil {
				return
			}
			if err := rc.Flush(); err != nil {
				return
			}
		case <-ticker.C:
			_ = rc.SetWriteDeadline(time.Now().Add(SSE_WRITE_TIMEOUT))
			if _, err := fmt.Fprint(w, ": keepalive\n\n"); err != nil {
				return
			}
			if err := rc.Flush(); err != nil {
				return
			}
		case <-r.Context().Done():
			return
		}
	}
}

// ============================================================
// [15] Statistics
// ============================================================
// getBlockedStats counts today's blocked queries by scanning
// /data/local/tmp/dnscrypt-blocked.log. Cached for 5 minutes.
//
// The scan runs OUTSIDE the cache mutex. A full read of a
// multi-megabyte log can take hundreds of milliseconds; holding
// statsMutex for the duration would block every concurrent
// SSE client that queries the stats.
func getBlockedStats() string {
	statsMutex.Lock()
	if time.Since(statsTime) < 300*time.Second && statsCache != "" {
		v := statsCache
		statsMutex.Unlock()
		return v
	}
	statsMutex.Unlock()

	logFile := "/data/local/tmp/dnscrypt-blocked.log"
	today := time.Now().Format("2006-01-02")

	f, err := os.Open(logFile)
	if err != nil {
		statsMutex.Lock()
		statsCache = "0"
		statsTime = time.Now()
		statsMutex.Unlock()
		return "0"
	}
	defer f.Close()

	count := 0
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		if strings.Contains(scanner.Text(), today) {
			count++
		}
	}

	result := strconv.Itoa(count)
	statsMutex.Lock()
	statsCache = result
	statsTime = time.Now()
	statsMutex.Unlock()
	return result
}

// getResourceUsage reads RSS from /proc/<pid>/statm for the
// DNS engine. Cached for 10 seconds.
//
// Before reading statm, the PID from the PID file is validated
// against /proc/<pid>/comm — the same check used by
// isPidAlive(). Without it, a PID reused by an unrelated
// process after a reboot would be reported as the DNS engine's
// RSS in the Dashboard's "RAM" row.
func getResourceUsage() string {
	resourceMutex.Lock()
	defer resourceMutex.Unlock()
	if time.Since(resourceTime) < 10*time.Second && resourceCache != "" {
		return resourceCache
	}
	pidData, err := os.ReadFile(PID_FILE)
	if err != nil {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}
	pid := strings.TrimSpace(string(pidData))
	if pid == "" {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}

	// Reject a PID whose comm is not one of the module binaries.
	commData, err := os.ReadFile("/proc/" + pid + "/comm")
	if err != nil {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}
	comm := strings.TrimSpace(string(commData))
	if comm != "dnscrypt-proxy" && comm != "dnscrypt-webui" {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}

	data, err := os.ReadFile("/proc/" + pid + "/statm")
	if err != nil {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}
	fields := strings.Fields(string(data))
	if len(fields) < 2 {
		resourceCache = "N/A"
		resourceTime = time.Now()
		return resourceCache
	}
	rssPages, _ := strconv.ParseInt(fields[1], 10, 64)
	resourceCache = fmt.Sprintf("%d MB", rssPages*4/1024)
	resourceTime = time.Now()
	return resourceCache
}

// ============================================================
// [16] Local request detection
// ============================================================
// isLocalRequest reports whether the request originated from
// the loopback interface.
//
// The host from net.SplitHostPort is always an IP literal (the
// string "localhost" is resolved by the client before the TCP
// handshake, so it never appears here).
//
// Uses net.IP.IsLoopback() rather than a string comparison
// against "127.0.0.1" / "::1". This correctly accepts:
//
//   - any 127.0.0.0/8 address (not only 127.0.0.1),
//   - IPv4-mapped IPv6 forms like ::ffff:127.0.0.1 that
//     net.SplitHostPort produces for IPv6 dual-stack listeners.
//
// net.ParseIP returns nil for non-IP strings; those are rejected
// (fail-closed).
func isLocalRequest(r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	host = strings.Trim(host, "[]")
	if ip := net.ParseIP(host); ip != nil {
		return ip.IsLoopback()
	}
	return false
}

func getClientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return strings.Trim(r.RemoteAddr, "[]")
	}
	return host
}

// ============================================================
// [17] Authentication
// ============================================================
// getMonitoringAuth returns the credentials from the
// [monitoring_ui] section of dnscrypt-proxy.toml, with a 60 s
// cache. Empty credentials disable auth (see checkAuth).
func getMonitoringAuth() (username, password string) {
	authCacheMu.RLock()
	if !authCacheTime.IsZero() && time.Since(authCacheTime) < AUTH_CACHE_TTL {
		u, p := authCacheUser, authCachePass
		authCacheMu.RUnlock()
		if u != "" || p != "" {
			return u, p
		}
	} else {
		authCacheMu.RUnlock()
	}

	user, pass := readMonitoringAuthFromFile()

	authCacheMu.Lock()
	if user != "" || pass != "" {
		authCacheUser = user
		authCachePass = pass
		authCacheTime = time.Now()
	} else {
		authCacheUser = ""
		authCachePass = ""
		authCacheTime = time.Time{}
	}
	authCacheMu.Unlock()

	return user, pass
}

// parseTOMLValue extracts a value from a TOML right-hand side.
//
// Quoted values (single or double) are returned verbatim between
// the delimiters — a '#' inside the quotes is NOT a comment.
// This is the TOML spec behavior: comments are only recognized
// outside of strings.
//
// Unquoted values have their inline " #" comment stripped and
// surrounding whitespace trimmed.
//
// The function intentionally does not unescape TOML escapes
// (\n, \", ...) — the credentials generated by customize.sh
// never contain them, and full TOML parsing would require a
// dedicated library.
func parseTOMLValue(s string) string {
	if len(s) == 0 {
		return ""
	}

	// Quoted value: content is verbatim between the delimiters.
	if s[0] == '"' || s[0] == '\'' {
		quote := s[0]
		if end := strings.IndexByte(s[1:], quote); end >= 0 {
			return s[1 : end+1]
		}
		// Unterminated quote — fall through to unquoted handling.
	}

	// Unquoted value: an inline " #" starts a comment.
	if idx := strings.Index(s, " #"); idx > 0 {
		s = strings.TrimSpace(s[:idx])
	}
	return s
}

// readMonitoringAuthFromFile parses ONLY the [monitoring_ui]
// section. Credentials in other sections are ignored.
//
// On panic, both return values are reset to empty. A partial
// read (one field populated, the other empty) MUST NOT reach
// getMonitoringAuth's cache — that function only caches when at
// least one field is non-empty, so a partial read would produce
// permanently broken credentials until restart.
func readMonitoringAuthFromFile() (username, password string) {
	defer func() {
		if recover() != nil {
			username, password = "", ""
		}
	}()

	data, err := os.ReadFile(CONF)
	if err != nil {
		return "", ""
	}

	inSection := false
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		if strings.HasPrefix(trimmed, "[") {
			if end := strings.Index(trimmed, "]"); end > 0 {
				section := strings.TrimSpace(trimmed[1:end])
				inSection = (section == "monitoring_ui")
				continue
			}
		}

		if !inSection {
			continue
		}

		eqIdx := strings.Index(trimmed, "=")
		if eqIdx <= 0 {
			continue
		}

		key := strings.TrimSpace(trimmed[:eqIdx])
		val := parseTOMLValue(strings.TrimSpace(trimmed[eqIdx+1:]))

		switch key {
		case "username":
			username = val
		case "password":
			password = val
		}
	}

	return username, password
}

// ============================================================
// [17b] Watchdog token
// ============================================================
// loadOrCreateWatchdogToken reads the token file or generates a
// fresh 32-byte token. Written atomically with mode 0600.
func loadOrCreateWatchdogToken() string {
	if data, err := os.ReadFile(WATCHDOG_TOKEN_FILE); err == nil {
		tok := strings.TrimSpace(string(data))
		if len(tok) >= 32 {
			return tok
		}
	}

	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		logWithLevel("warn", "⚠️ Failed to generate watchdog token: "+err.Error())
		return ""
	}
	tok := hex.EncodeToString(b)

	if err := atomicWriteFile(WATCHDOG_TOKEN_FILE, []byte(tok), 0600); err != nil {
		logWithLevel("warn", "⚠️ Failed to persist watchdog token: "+err.Error())
	}

	return tok
}

// getWatchdogToken returns the token, generating it once if
// missing. Cached for the process lifetime.
func getWatchdogToken() string {
	watchdogTokMu.RLock()
	if !watchdogTokTime.IsZero() {
		v := watchdogTokValue
		watchdogTokMu.RUnlock()
		return v
	}
	watchdogTokMu.RUnlock()

	watchdogTokMu.Lock()
	defer watchdogTokMu.Unlock()
	if !watchdogTokTime.IsZero() {
		return watchdogTokValue
	}

	tok := loadOrCreateWatchdogToken()
	watchdogTokValue = tok
	watchdogTokTime = time.Now()
	return tok
}

// verifyWatchdogToken constant-time-compares the header value
// against the expected token.
func verifyWatchdogToken(r *http.Request) bool {
	expected := getWatchdogToken()
	if expected == "" {
		return false
	}
	provided := r.Header.Get(WATCHDOG_TOKEN_HEADER)
	if provided == "" {
		return false
	}
	if len(provided) != len(expected) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) == 1
}

// ============================================================
// [17c] Sessions
// ============================================================
// createSession generates a 32-byte hex token, stores it in
// the session map, and returns it. Expired sessions are pruned
// lazily on every call.
func createSession(username string) string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return ""
	}
	token := hex.EncodeToString(b)
	now := time.Now()
	sessionsMu.Lock()
	for k, v := range sessions {
		if v.ExpiresAt.Before(now) {
			delete(sessions, k)
		}
	}
	sessions[token] = &Session{
		Username:  username,
		CreatedAt: now,
		ExpiresAt: now.Add(SESSION_TTL),
	}
	sessionsMu.Unlock()
	return token
}

// getSession returns the session associated with the request's
// cookie, extending its TTL on every hit.
func getSession(r *http.Request) *Session {
	cookie, err := r.Cookie(SESSION_COOKIE_NAME)
	if err != nil {
		return nil
	}

	sessionsMu.Lock()
	defer sessionsMu.Unlock()

	sess := sessions[cookie.Value]
	if sess == nil {
		return nil
	}
	if sess.ExpiresAt.Before(time.Now()) {
		delete(sessions, cookie.Value)
		return nil
	}
	sess.ExpiresAt = time.Now().Add(SESSION_TTL)
	return sess
}

// validateBearerToken accepts an Authorization: Bearer <token>
// header whose value matches a live session.
func validateBearerToken(r *http.Request) bool {
	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return false
	}
	token := strings.TrimPrefix(authHeader, "Bearer ")
	if token == "" {
		return false
	}

	sessionsMu.Lock()
	defer sessionsMu.Unlock()

	sess := sessions[token]
	if sess == nil {
		return false
	}
	if sess.ExpiresAt.Before(time.Now()) {
		delete(sessions, token)
		return false
	}
	sess.ExpiresAt = time.Now().Add(SESSION_TTL)
	return true
}

func destroySession(token string) {
	sessionsMu.Lock()
	delete(sessions, token)
	sessionsMu.Unlock()
}

// checkAuth is the single auth entry point. Order of checks:
//  1. Watchdog token (POST /api/ensure_running_service from
//     localhost only).
//  2. Empty credentials → no auth required.
//  3. Bearer token / session cookie / Basic Auth.
//
// Basic Auth failures feed the per-IP login rate limiter.
func checkAuth(r *http.Request) bool {
	if hasEndpoint(r.URL.Path, "ensure_running_service") {
		if r.Method == http.MethodPost && isLocalRequest(r) {
			if verifyWatchdogToken(r) {
				return true
			}
		}
	}

	expectedUser, expectedPass := getMonitoringAuth()
	if expectedUser == "" && expectedPass == "" {
		return true
	}

	if validateBearerToken(r) {
		return true
	}

	if getSession(r) != nil {
		return true
	}

	user, pass, ok := r.BasicAuth()
	if ok {
		ip := getClientIP(r)

		if isLockedOut(ip) {
			return false
		}

		userMatch := subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) == 1
		passMatch := subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
		if userMatch && passMatch {
			recordLoginAttempt(ip, true)
			return true
		}

		recordLoginAttempt(ip, false)
	}
	return false
}

// ============================================================
// [17d] Companion app install helpers
// ============================================================
//
// State:
//   installTokens   — one-shot CSRF tokens (60 s TTL)
//   installAttempts — per-IP rate limiter (5 fails / 15 min)
//
// Auth flow (all endpoints under /api/*):
//   1. checkAuth(r)          — session cookie / bearer / basic
//   2. isLocalRequest(r)     — loopback only
//   3. isInstallLockedOut(ip) — rate limiter
//   4. validateAndConsumeInstallToken(tok) — one-shot

// getInstallScript returns the absolute path to install_app.sh.
// Searches two candidates (mirrors getFunctionsScript):
//  1. $MODDIR/install_app.sh  — post-install layout
//     (staged by customize.sh §[9])
//  2. $PROXYDIR/install_app.sh — source-tree layout
//     (running main.go from the repository root)
//
// Falls back to the post-install path when neither exists,
// so the caller's "script_not_found" branch produces a
// meaningful diagnostic.
func getInstallScript() string {
	candidates := []string{
		filepath.Join(MODDIR, INSTALL_SCRIPT_REL),
		filepath.Join(PROXYDIR, INSTALL_SCRIPT_REL),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return filepath.Join(MODDIR, INSTALL_SCRIPT_REL)
}

// generateInstallToken issues a one-shot CSRF token. Expired
// tokens are pruned lazily on every call.
func generateInstallToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return ""
	}
	tok := hex.EncodeToString(b)

	installTokensMu.Lock()
	now := time.Now()
	for k, v := range installTokens {
		if v.ExpiresAt.Before(now) {
			delete(installTokens, k)
		}
	}
	installTokens[tok] = &InstallToken{
		Value:     tok,
		ExpiresAt: now.Add(INSTALL_TOKEN_TTL),
		Used:      false,
	}
	installTokensMu.Unlock()

	return tok
}

// validateAndConsumeInstallToken marks a token as used so it
// cannot be replayed. Returns false for expired/used/unknown.
//
// Comparison is constant-time (subtle.ConstantTimeCompare).
// A plain map lookup would leak timing information about how
// many bytes of a supplied token prefix match a stored entry.
//
// The comparison runs against EVERY stored token — including
// expired and already-used ones — and is evaluated BEFORE the
// expiry check, so every iteration has identical cost. Map
// iteration order in Go is randomized per call, so the
// comparison cost also does not reveal the entry's position.
//
// Complexity is O(n) with n ≤ MAX_INSTALL_ATTEMPTS (5) tokens
// outstanding, so the extra work is negligible (~1 µs per
// request even on constrained devices).
func validateAndConsumeInstallToken(tok string) bool {
	if tok == "" {
		return false
	}

	installTokensMu.Lock()
	defer installTokensMu.Unlock()

	now := time.Now()
	tokBytes := []byte(tok)

	var matched *InstallToken

	for k, v := range installTokens {
		cmpResult := subtle.ConstantTimeCompare(tokBytes, []byte(k))

		if v.ExpiresAt.Before(now) {
			delete(installTokens, k)
			continue
		}

		if cmpResult == 1 && !v.Used {
			matched = v
		}
	}

	if matched == nil {
		return false
	}

	matched.Used = true
	return true
}

// recordInstallAttempt updates the per-IP install rate limiter.
// Success clears the counter; failure increments it and locks
// out when MAX_INSTALL_ATTEMPTS is reached.
func recordInstallAttempt(ip string, success bool) {
	installAttemptsMu.Lock()
	defer installAttemptsMu.Unlock()

	if success {
		delete(installAttempts, ip)
		return
	}

	a := installAttempts[ip]
	if a == nil {
		a = &InstallAttempt{}
		installAttempts[ip] = a
	}
	a.Count++
	a.LastAttempt = time.Now()
	if a.Count >= MAX_INSTALL_ATTEMPTS {
		a.LockedUntil = time.Now().Add(INSTALL_LOCKOUT_PERIOD)
		a.Count = 0
	}
}

func isInstallLockedOut(ip string) bool {
	installAttemptsMu.Lock()
	defer installAttemptsMu.Unlock()

	a := installAttempts[ip]
	if a == nil {
		return false
	}
	if a.LockedUntil.IsZero() {
		return false
	}
	if a.LockedUntil.Before(time.Now()) {
		delete(installAttempts, ip)
		return false
	}
	return true
}

// invalidateCompanionStateCache clears the companion-app state
// cache so the next companion_app_state request triggers a
// fresh probe of the live install state.
//
// Called unconditionally after every install/uninstall attempt
// (success OR failure). A failed install may still register the
// package after install_app.sh's internal poll timed out.
func invalidateCompanionStateCache() {
	companionStateMutex.Lock()
	companionStateTime = time.Time{}
	companionStateCache = ""
	companionStateMutex.Unlock()
}

// callInstallScript runs install_app.sh with the given mode and
// parses its single-line JSON output.
//
// stderr is captured through a bounded limitedBuffer to keep
// the process heap bounded if install_app.sh emits long
// diagnostics.
func callInstallScript(mode string) map[string]interface{} {
	script := getInstallScript()
	if _, err := os.Stat(script); err != nil {
		return map[string]interface{}{
			"status":  "error",
			"action":  mode,
			"reason":  "script_not_found",
			"message": "install_app.sh not found at " + script,
		}
	}

	shell := getSystemShell()
	var cmd string
	switch mode {
	case "install":
		cmd = shell + " " + shellQuote(script)
	case "status":
		cmd = shell + " " + shellQuote(script) + " --status"
	case "uninstall":
		cmd = shell + " " + shellQuote(script) + " --uninstall"
	default:
		return map[string]interface{}{
			"status":  "error",
			"reason":  "invalid_mode",
			"message": "unknown install mode: " + mode,
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), INSTALL_TIMEOUT)
	defer cancel()

	command := exec.CommandContext(ctx, shell, "-c", cmd)
	command.Env = shellEnv()

	var outBuf bytes.Buffer
	command.Stdout = &outBuf

	errBuf := &limitedBuffer{max: MAX_STDERR_CAPTURE}
	command.Stderr = errBuf

	err := command.Run()
	raw := strings.TrimSpace(outBuf.String())

	var parsed map[string]interface{}
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var m map[string]interface{}
		if json.Unmarshal([]byte(line), &m) == nil {
			parsed = m
		}
	}

	if parsed == nil {
		msg := "install_app.sh produced no JSON output"
		if err != nil {
			msg += " (error: " + err.Error() + ")"
		}
		errOut := strings.TrimSpace(errBuf.String())
		if errOut != "" {
			msg += " stderr: " + errOut
		}
		logWithLevel("warn", "callInstallScript("+mode+"): "+msg)
		return map[string]interface{}{
			"status":  "error",
			"action":  mode,
			"reason":  "no_json_output",
			"message": msg,
		}
	}

	return parsed
}

// installCompanionApp performs the full install flow:
//  1. per-IP rate limit check
//  2. one-shot CSRF token validation
//  3. shell out to install_app.sh
//  4. record the outcome
//  5. invalidate the companion-state cache
//
// All error responses carry the `action` field so the client
// can render a single unified install UI. The 429 message is
// aligned with docs/REFERENCE.md §2.3.2 and SECURITY.md §5.36.2.
func installCompanionApp(r *http.Request) map[string]interface{} {
	ip := getClientIP(r)

	if isInstallLockedOut(ip) {
		return map[string]interface{}{
			"status":  "error",
			"action":  "install",
			"message": "Too many install attempts. Try again in 15 minutes.",
			"reason":  "rate_limited",
		}
	}

	tok := r.FormValue("token")
	if !validateAndConsumeInstallToken(tok) {
		recordInstallAttempt(ip, false)
		return map[string]interface{}{
			"status":  "error",
			"action":  "install",
			"message": "Invalid or expired install token",
			"reason":  "invalid_token",
		}
	}

	logEvent("📲 install_companion_app requested by " + sanitizeLogText(ip))
	result := callInstallScript("install")

	if result["status"] == "ok" {
		recordInstallAttempt(ip, true)
	} else {
		recordInstallAttempt(ip, false)
	}

	invalidateCompanionStateCache()
	return result
}

// uninstallCompanionApp shells out to install_app.sh --uninstall.
// Auth + localhost gate are applied upstream in handleAPI.
func uninstallCompanionApp() map[string]interface{} {
	logEvent("🗑 uninstall_companion_app requested")
	result := callInstallScript("uninstall")
	invalidateCompanionStateCache()
	return result
}

// getCompanionState returns the cached companion-app install
// state, refreshing it via install_app.sh --status when the
// cache has expired.
//
// Three-phase read:
//  1. Short critical section — cache lookup.
//  2. Probe OUTSIDE the lock (up to INSTALL_TIMEOUT).
//  3. Short critical section — store the result, returning
//     the cached entry if another goroutine refreshed it in
//     the meantime (both results are fresh; the caller gets
//     one of them).
func getCompanionState() map[string]interface{} {
	companionStateMutex.Lock()
	if !companionStateTime.IsZero() &&
		time.Since(companionStateTime) < COMPANION_STATE_CACHE_TTL {
		var cached map[string]interface{}
		if json.Unmarshal([]byte(companionStateCache), &cached) == nil {
			companionStateMutex.Unlock()
			return cached
		}
	}
	companionStateMutex.Unlock()

	result := callInstallScript("status")

	if companionStateMutex.TryLock() {
		if !companionStateTime.IsZero() &&
			time.Since(companionStateTime) < COMPANION_STATE_CACHE_TTL {
			var cached map[string]interface{}
			if json.Unmarshal([]byte(companionStateCache), &cached) == nil {
				companionStateMutex.Unlock()
				return cached
			}
		}
		if b, err := json.Marshal(result); err == nil {
			companionStateCache = string(b)
			companionStateTime = time.Now()
		}
		companionStateMutex.Unlock()
	}

	return result
}

// ============================================================
// [18] Session GC + rate limiting
// ============================================================
// startSessionGC runs a periodic cleanup every SESSION_GC_PERIOD
// (30 min). It prunes:
//   - sessions        — expired entries
//   - loginAttempts   — entries older than LOGIN_ATTEMPT_STALE_PERIOD
//   - installAttempts — same staleness rule
//
// installTokens is NOT garbage-collected here — it has its own
// lazy GC inside generateInstallToken().
//
// Staleness rule for both rate-limiter maps:
//   - Not locked out: stale if LastAttempt is older than 1 h.
//   - Locked out:     stale if LockedUntil passed over 1 h ago.
func startSessionGC() {
	go func() {
		ticker := time.NewTicker(SESSION_GC_PERIOD)
		defer ticker.Stop()
		for range ticker.C {
			now := time.Now()

			sessionsMu.Lock()
			sessRemoved := 0
			for k, v := range sessions {
				if v.ExpiresAt.Before(now) {
					delete(sessions, k)
					sessRemoved++
				}
			}
			sessionsMu.Unlock()

			loginAttemptsMu.Lock()
			attemptsRemoved := 0
			for ip, attempt := range loginAttempts {
				if attempt == nil {
					delete(loginAttempts, ip)
					attemptsRemoved++
					continue
				}

				stale := false
				if attempt.LockedUntil.IsZero() {
					if now.Sub(attempt.LastAttempt) > LOGIN_ATTEMPT_STALE_PERIOD {
						stale = true
					}
				} else if attempt.LockedUntil.Before(now) {
					if now.Sub(attempt.LockedUntil) > LOGIN_ATTEMPT_STALE_PERIOD {
						stale = true
					}
				}

				if stale {
					delete(loginAttempts, ip)
					attemptsRemoved++
				}
			}
			loginAttemptsMu.Unlock()

			installAttemptsMu.Lock()
			installRemoved := 0
			for ip, attempt := range installAttempts {
				if attempt == nil {
					delete(installAttempts, ip)
					installRemoved++
					continue
				}

				stale := false
				if attempt.LockedUntil.IsZero() {
					if now.Sub(attempt.LastAttempt) > LOGIN_ATTEMPT_STALE_PERIOD {
						stale = true
					}
				} else if attempt.LockedUntil.Before(now) {
					if now.Sub(attempt.LockedUntil) > LOGIN_ATTEMPT_STALE_PERIOD {
						stale = true
					}
				}

				if stale {
					delete(installAttempts, ip)
					installRemoved++
				}
			}
			installAttemptsMu.Unlock()

			if sessRemoved > 0 || attemptsRemoved > 0 || installRemoved > 0 {
				logWithLevel("debug", fmt.Sprintf(
					"🧹 GC removed: %d session(s), %d login attempt(s), %d install attempt(s)",
					sessRemoved, attemptsRemoved, installRemoved))
			}
		}
	}()
}

// recordLoginAttempt updates the per-IP login rate limiter.
// Success clears the counter; failure increments it and locks
// out when MAX_LOGIN_ATTEMPTS is reached.
func recordLoginAttempt(ip string, success bool) {
	loginAttemptsMu.Lock()
	defer loginAttemptsMu.Unlock()

	if success {
		delete(loginAttempts, ip)
		return
	}

	attempt := loginAttempts[ip]
	if attempt == nil {
		attempt = &LoginAttempt{}
		loginAttempts[ip] = attempt
	}
	attempt.Count++
	attempt.LastAttempt = time.Now()
	if attempt.Count >= MAX_LOGIN_ATTEMPTS {
		attempt.LockedUntil = time.Now().Add(LOGIN_LOCKOUT_PERIOD)
		attempt.Count = 0
	}
}

func isLockedOut(ip string) bool {
	loginAttemptsMu.Lock()
	defer loginAttemptsMu.Unlock()
	attempt := loginAttempts[ip]
	if attempt == nil {
		return false
	}
	if attempt.LockedUntil.IsZero() {
		return false
	}
	if attempt.LockedUntil.Before(time.Now()) {
		delete(loginAttempts, ip)
		return false
	}
	return true
}

// ============================================================
// [19] Process and port checks
// ============================================================
// isPidAlive returns true only when the PID's comm matches one
// of the module's binaries — this catches PID reuse by an
// unrelated process.
func isPidAlive(pid int) bool {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
	if err != nil {
		return false
	}
	comm := strings.TrimSpace(string(data))
	switch comm {
	case "dnscrypt-proxy", "dnscrypt-webui":
		return true
	}
	return false
}

// isProcessRunning prefers the PID file (with comm validation);
// falls back to `pgrep -x dnscrypt-proxy`.
func isProcessRunning() (string, bool) {
	defer func() { recover() }()
	if data, err := os.ReadFile(PID_FILE); err == nil {
		pidStr := strings.TrimSpace(string(data))
		if pidStr != "" {
			pidInt, _ := strconv.Atoi(pidStr)
			if isPidAlive(pidInt) {
				return pidStr, true
			}
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "pgrep", "-x", "dnscrypt-proxy").CombinedOutput()
	if err == nil {
		if pid := strings.TrimSpace(string(out)); pid != "" {
			return pid, true
		}
	}
	return "", false
}

// isPortOpen probes a UDP port. Fast path reads /proc/net/udp
// and /proc/net/udp6; slow path falls back to functions.sh's
// is_port_open (bounded by PORT_PROBE_TIMEOUT — probes run on
// the SSE / stats path and must fail fast).
func isPortOpen(port int) bool {
	defer func() { recover() }()

	hexPort := fmt.Sprintf("%04X", port)
	needle := []byte(":" + hexPort + " ")

	readable := false
	for _, procFile := range []string{"/proc/net/udp", "/proc/net/udp6"} {
		data, err := os.ReadFile(procFile)
		if err != nil {
			continue
		}
		readable = true
		if bytes.Contains(data, needle) {
			return true
		}
	}

	if readable {
		return false
	}

	cmd := fmt.Sprintf(". %s; is_port_open %d udp", shellQuote(getFunctionsScript()), port)
	return runShellWithTimeout(cmd, PORT_PROBE_TIMEOUT) == nil
}

// isPortOpenCached wraps isPortOpen with a PORT_CACHE_TTL
// window (5 s).
func isPortOpenCached(port int) bool {
	portCacheMu.Lock()
	defer portCacheMu.Unlock()

	if entry, ok := portCacheMap[port]; ok {
		if time.Since(entry.time) < PORT_CACHE_TTL {
			return entry.open
		}
	}

	open := isPortOpen(port)
	portCacheMap[port] = portCacheEntry{open: open, time: time.Now()}
	return open
}

// getStatusUncached reports ON only when the DNS engine process
// is alive AND its 5354/udp socket is listening.
func getStatusUncached() (status string) {
	status = "OFF"
	defer func() {
		if r := recover(); r != nil {
			logWithLevel("debug", fmt.Sprintf("getStatusUncached panic: %v", r))
			status = "OFF"
		}
	}()

	_, found := isProcessRunning()
	if !found || !isPortOpenCached(5354) {
		return "OFF"
	}
	return "ON"
}

// getStatus caches the DNS engine status for STATUS_CACHE_TTL
// (2 s) — many handlers call it within a single request burst.
func getStatus() string {
	statusCacheMutex.Lock()
	defer statusCacheMutex.Unlock()
	if time.Since(cachedStatusTime) < STATUS_CACHE_TTL && cachedStatusVal != "" {
		return cachedStatusVal
	}
	cachedStatusVal = getStatusUncached()
	cachedStatusTime = time.Now()
	return cachedStatusVal
}

func invalidateStatusCache() {
	statusCacheMutex.Lock()
	cachedStatusTime = time.Time{}
	cachedStatusVal = ""
	statusCacheMutex.Unlock()
}

// waitForProcessAndPort polls until the DNS engine is both
// alive and listening, or the timeout elapses.
func waitForProcessAndPort(timeout time.Duration) bool {
	defer func() { recover() }()
	start := time.Now()
	for time.Since(start) < timeout {
		if _, found := isProcessRunning(); found && isPortOpen(5354) {
			return true
		}
		time.Sleep(500 * time.Millisecond)
	}
	return false
}

func ensureExecutable(path string) bool {
	defer func() { recover() }()
	fi, err := os.Stat(path)
	if err != nil {
		return false
	}
	if fi.Mode().Perm()&0111 == 0 {
		os.Chmod(path, 0755)
	}
	return true
}

// ============================================================
// [20] Service lifecycle
// ============================================================
// startService launches the DNS engine, waits for it to bind,
// installs firewall rules, and updates STATUS_FILE.
//
// Port-cache invalidation: getStatus() consults
// isPortOpenCached(5354), which has a 5-second TTL. A stale
// entry from a previous run (or a socket still held by a
// dying process) could otherwise report "ON" and short-circuit
// the start, leaving the module stuck with no working DNS.
//
// Firewall timeout: manage_firewall 1 iterates over up to 32
// bootstrap IPs × 2 protocols × 2 strategies (chain + direct
// DNAT fallback), each guarded by `iptables --wait 5`. Under
// contention with netd this can exceed the 15 s default
// runShell budget. 90 s gives headroom without hanging forever.
func startService() {
	defer func() { recover() }()
	logEvent("▶️ Starting service...")

	portCacheMu.Lock()
	portCacheMap = make(map[int]portCacheEntry)
	portCacheMu.Unlock()

	invalidateStatusCache()
	if getStatus() == "ON" {
		return
	}
	if !ensureExecutable(BIN) {
		return
	}
	runShell(". " + shellQuote(getFunctionsScript()) + "; cleanup_proxy")
	time.Sleep(500 * time.Millisecond)

	cmd := exec.Command(BIN, "-config", CONF)
	cmd.Dir = PROXYDIR
	if err := cmd.Start(); err != nil {
		logWithLevel("error", "❌ Failed to start dnscrypt-proxy: "+err.Error())
		return
	}
	pid := cmd.Process.Pid
	go func() {
		if err := cmd.Wait(); err != nil {
			logEvent(fmt.Sprintf("ℹ️ dnscrypt-proxy %d exited: %v", pid, err))
		}
	}()

	atomicWriteFile(PID_FILE, []byte(strconv.Itoa(pid)), 0666)

	if !waitForProcessAndPort(SERVICE_START_TIMEOUT) {
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
		runShell("pkill -9 dnscrypt-proxy")
		runShell(". " + shellQuote(getFunctionsScript()) + "; cleanup_proxy")
		os.Remove(PID_FILE)
		atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
		invalidateStatusCache()
		return
	}
	runShell("settings delete global private_dns_mode")
	runShellWithTimeout(
		". "+shellQuote(getFunctionsScript())+"; manage_firewall 1",
		90*time.Second)
	atomicWriteFile(STATUS_FILE, []byte("ON"), 0666)
	invalidateStatusCache()
	logEvent("✅ Service started (PID: " + strconv.Itoa(pid) + ")")
	runShell("ndc resolver flushdefaultif 2>/dev/null || true")
	broadcastEvent("status", "ON")
	broadcastEvent("resources", fmt.Sprintf("{\"ram\":\"%s\"}", getResourceUsage()))
}

// stopService kills the DNS engine, tears down the firewall,
// and writes STATUS_FILE = OFF.
//
// PID-file removal is elevated to a warn-level log: a stale
// PID file combined with the watchdog could cause a restart
// attempt against an unrelated PID (mitigated by isPidAlive's
// comm check, but the log line is the operator's only signal).
//
// Firewall timeout: same 90 s budget as startService — the
// blind cleanup path (mode 0) is faster than mode 1 but still
// issues multiple iptables calls that can contend with netd.
func stopService() {
	defer func() { recover() }()
	logEvent("⏹️ Stopping service...")
	portCacheMu.Lock()
	portCacheMap = make(map[int]portCacheEntry)
	portCacheMu.Unlock()
	atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	invalidateStatusCache()

	runShell("pkill -9 dnscrypt-proxy")
	runShell(". " + shellQuote(getFunctionsScript()) + "; cleanup_proxy")
	if err := os.Remove(PID_FILE); err != nil && !os.IsNotExist(err) {
		logWithLevel("warn", "stopService: could not remove PID file: "+err.Error())
	}
	runShellWithTimeout(
		". "+shellQuote(getFunctionsScript())+"; manage_firewall 0",
		90*time.Second)
	atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	invalidateStatusCache()
	logEvent("✅ Service stopped")
	broadcastEvent("status", "OFF")
	broadcastEvent("resources", "{\"ram\":\"N/A\"}")
}

// reloadService sends SIGHUP when the engine is running, else
// it starts the service.
func reloadService() {
	serviceMutex.Lock()
	defer serviceMutex.Unlock()
	defer func() { recover() }()
	if getStatus() == "ON" {
		runShell("pkill -HUP dnscrypt-proxy")
		logEvent("✅ Service reloaded (HUP)")
	} else {
		startService()
	}
}

func restartService() {
	defer func() { recover() }()
	logEvent("🔄 Restarting service...")
	stopService()
	time.Sleep(500 * time.Millisecond)
	startService()
	invalidateStatusCache()
	broadcastEvent("status", getStatus())
}

// ============================================================
// [21] getEntriesCount + validate + internet + progress
// ============================================================
// getEntriesCount counts newlines in blocklist.txt.
//
// Cache key: (size, mtime, inode). The inode field guards
// against same-second same-size writes on filesystems with
// coarse mtime resolution.
func getEntriesCount() int {
	defer func() { recover() }()

	countCacheMu.Lock()
	defer countCacheMu.Unlock()

	fi, err := os.Stat(BLOCKLIST_FILE)
	if err != nil || fi.Size() == 0 {
		return 0
	}

	inode := inodeOf(fi)

	if fi.Size() == lastSize && lastSize > 0 &&
		fi.ModTime().Equal(lastModTime) &&
		inode == lastInode {
		return cachedCount
	}

	f, err := os.Open(BLOCKLIST_FILE)
	if err != nil {
		return 0
	}
	defer f.Close()

	buf := make([]byte, 32*1024)
	count := 0
	for {
		c, err := f.Read(buf)
		if c > 0 {
			for i := 0; i < c; i++ {
				if buf[i] == '\n' {
					count++
				}
			}
		}
		if err == io.EOF || err != nil {
			break
		}
	}
	cachedCount = count
	lastSize = fi.Size()
	lastModTime = fi.ModTime()
	lastInode = inode
	return count
}

// inodeOf extracts the inode from os.FileInfo on Linux/Android.
// Returns 0 if the type assertion fails — the cache degrades to
// the (size, mtime) key, which is correct, just less strict.
func inodeOf(fi os.FileInfo) uint64 {
	if st, ok := fi.Sys().(*syscall.Stat_t); ok {
		return st.Ino
	}
	return 0
}

// validateBlocklist rejects files that are too small or that
// have no valid domain/IP entries in the first 500 lines.
func validateBlocklist(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("cannot stat file: %v", err)
	}
	if info.Size() < MIN_BLOCKLIST_SIZE {
		return fmt.Errorf("file too small (%d bytes)", info.Size())
	}
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024*1024), 2*1024*1024)
	lineCount := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		lineCount++
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.Contains(line, ".") || strings.Contains(line, ":") {
			return nil
		}
		if lineCount > 500 {
			break
		}
	}
	return fmt.Errorf("no valid domain/IP entries in first 500 lines")
}

// isInternetAvailable prefers a quick radio-state check via
// `getprop`; falls back to HEAD probes against three public
// resolvers.
func isInternetAvailable() bool {
	defer func() { recover() }()
	out, err := exec.Command("getprop", "gsm.network.type").Output()
	if err == nil {
		netType := strings.TrimSpace(string(out))
		if netType != "" && !strings.Contains(netType, "Unknown") {
			return true
		}
	}
	out, err = exec.Command("getprop", "wifi.interface").Output()
	if err == nil && strings.TrimSpace(string(out)) != "" {
		return true
	}

	client := &http.Client{Timeout: 3 * time.Second}
	for _, url := range []string{"https://1.1.1.1", "https://9.9.9.9", "https://8.8.8.8"} {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		req, err := newHTTPRequest(ctx, http.MethodHead, url, nil)
		if err == nil {
			resp, err := client.Do(req)
			if err == nil {
				resp.Body.Close()
				cancel()
				if resp.StatusCode < 500 {
					return true
				}
			}
		}
		cancel()
	}
	return false
}

// writeProgress atomically updates PROGRESS_FILE and broadcasts
// the value over SSE.
//
// The message is sanitized: `|` is the field separator between
// percent and message in the file format (parsed by
// /api?action=get_progress), so any `|` in the message would
// shift the parse. Mirrors the shell-side write_progress() in
// functions.sh.
func writeProgress(percent int, msg string) {
	msg = strings.ReplaceAll(msg, "|", "/")
	atomicWriteFile(PROGRESS_FILE, []byte(fmt.Sprintf("%d|%s", percent, msg)), 0666)
	broadcastEvent("progress", fmt.Sprintf("%d|%s", percent, msg))
}

// ============================================================
// [22] Download with progress
// ============================================================
// downloadWithProgress streams a URL into dest via
// atomicWriteStream, reporting progress through the SSE channel
// every 5 percent.
func downloadWithProgress(urlStr, dest string) error {
	defer func() { recover() }()
	if !isInternetAvailable() {
		return errors.New("no internet connection")
	}

	ctx, cancel := context.WithTimeout(context.Background(), DOWNLOAD_TIMEOUT*time.Second)
	defer cancel()

	client := getDownloadClient()

	req, err := newHTTPRequest(ctx, http.MethodGet, urlStr, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		resetDownloadClient()
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP error: %d", resp.StatusCode)
	}

	if resp.ContentLength > MAX_BLOCKLIST_SIZE {
		return errors.New("file exceeds max size")
	}

	totalSize := resp.ContentLength
	if totalSize <= 0 {
		totalSize = 5 * 1024 * 1024
	}

	pw := &ProgressWriter{
		total:       totalSize,
		lastPercent: -1,
		onProgress:  writeProgress,
	}

	return atomicWriteStream(dest, 0644, func(w io.Writer) error {
		pw.writer = w
		limitReader := io.LimitReader(resp.Body, MAX_BLOCKLIST_SIZE)
		_, err := io.Copy(io.Discard, io.TeeReader(limitReader, pw))
		return err
	})
}

// ============================================================
// [23] Domain normalization
// ============================================================
// normalizeDomain strips common hosts-file prefixes (||, ^,
// *., .) and lowercases the result. Returns "" for comments and
// blank lines.
func normalizeDomain(line string) string {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "#") {
		return ""
	}
	line = strings.TrimPrefix(line, "||")
	line = strings.TrimSuffix(line, "^")
	line = strings.TrimPrefix(line, "*.")
	line = strings.TrimPrefix(line, ".")
	line = strings.ToLower(line)
	return line
}

// isDomainMatch reports whether `blocked` matches `allowed`,
// either exactly or as a subdomain.
func isDomainMatch(blocked, allowed string) bool {
	if blocked == "" || allowed == "" {
		return false
	}
	if blocked == allowed {
		return true
	}
	if len(blocked) > len(allowed) && strings.HasSuffix(blocked, "."+allowed) {
		return true
	}
	return false
}

// stripDenySections removes any prior deny sections from
// blocklist content before a rebuild.
func stripDenySections(content string) string {
	if idx := strings.Index(content, DENY_MARKER_START); idx >= 0 {
		content = content[:idx]
	}
	if idx := strings.Index(content, LEGACY_DENY_MARKER); idx >= 0 {
		content = content[:idx]
	}
	return strings.TrimRight(content, " \t\r\n") + "\n"
}

// isAllowedBySuffixes walks the domain's parent chain looking
// for any suffix present in allowSet.
func isAllowedBySuffixes(norm string, allowSet map[string]struct{}) bool {
	if norm == "" {
		return false
	}
	for {
		if _, ok := allowSet[norm]; ok {
			return true
		}
		idx := strings.IndexByte(norm, '.')
		if idx < 0 {
			return false
		}
		norm = norm[idx+1:]
	}
}

// ============================================================
// [24] Rebuild blocklist.txt
// ============================================================
// rebuildBlocklist streams blocklist.raw through the allowlist
// filter, appends the deny section, and writes blocklist.txt
// atomically. Serialized by rebuildMu.
func rebuildBlocklist() error {
	rebuildMu.Lock()
	defer rebuildMu.Unlock()

	allowSet := make(map[string]struct{})
	if allowData, err := os.ReadFile(ALLOWLIST_FILE); err == nil {
		for _, line := range strings.Split(string(allowData), "\n") {
			if d := normalizeDomain(line); d != "" {
				allowSet[d] = struct{}{}
			}
		}
	}

	var denyLines []string
	if denyData, err := os.ReadFile(DENYLIST_FILE); err == nil {
		for _, line := range strings.Split(string(denyData), "\n") {
			line = strings.TrimRight(line, " \t\r\n")
			line = strings.TrimLeft(line, " \t")
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			denyLines = append(denyLines, line)
		}
	}

	rawFile, err := os.Open(RAW_BLOCKLIST_FILE)
	if err != nil {
		return fmt.Errorf("open raw: %w", err)
	}
	defer rawFile.Close()

	removed := 0

	writeErr := atomicWriteStream(BLOCKLIST_FILE, 0644, func(w io.Writer) error {
		scanner := bufio.NewScanner(rawFile)
		scanner.Buffer(make([]byte, STREAM_READ_BUFFER), STREAM_MAX_LINE)

		for scanner.Scan() {
			line := scanner.Text()
			norm := normalizeDomain(line)

			if norm != "" && isAllowedBySuffixes(norm, allowSet) {
				removed++
				continue
			}

			if _, err := io.WriteString(w, line); err != nil {
				return err
			}
			if _, err := io.WriteString(w, "\n"); err != nil {
				return err
			}
		}

		if err := scanner.Err(); err != nil {
			return fmt.Errorf("scan raw: %w", err)
		}

		if len(denyLines) > 0 {
			if _, err := io.WriteString(w, DENY_MARKER_START+"\n"); err != nil {
				return err
			}
			for _, l := range denyLines {
				if _, err := io.WriteString(w, l+"\n"); err != nil {
					return err
				}
			}
			if _, err := io.WriteString(w, DENY_MARKER_END+"\n"); err != nil {
				return err
			}
		}

		return nil
	})

	if writeErr != nil {
		return fmt.Errorf("stream write: %w", writeErr)
	}

	countCacheMu.Lock()
	cachedCount = 0
	lastSize = 0
	lastModTime = time.Time{}
	lastInode = 0
	countCacheMu.Unlock()

	logEvent(fmt.Sprintf("✅ rebuildBlocklist (streamed): removed=%d, denied=%d", removed, len(denyLines)))
	return nil
}

// ============================================================
// [25] Atomic rules save
// ============================================================
type saveRulesRequest struct {
	AllowContent      string
	DenyContent       string
	ExpectedAllowHash string
	ExpectedDenyHash  string
	UpdateAllow       bool
	UpdateDeny        bool
}

type saveRulesResult struct {
	Status    string
	Changed   bool
	Message   string
	AllowHash string
	DenyHash  string
	Entries   int
}

var reloadServiceFn = func() { reloadService() }

func runAtomicSave(req saveRulesRequest, primary string) map[string]interface{} {
	result, shouldReload := atomicSaveRulesInternal(req)

	if shouldReload {
		reloadServiceFn()
		broadcastEvent("stats",
			fmt.Sprintf(`{"blocked_today":"%s"}`, getBlockedStats()))
	}

	primaryHash := result.AllowHash
	if primary == "deny" {
		primaryHash = result.DenyHash
	}
	return result.toMap(primaryHash)
}

// atomicSaveRulesInternal applies an allowlist/denylist change
// under rulesStateMu, restoring previous content on any failure.
//
// Two-phase conflict detection:
//  1. Pre-check against the caller's expected hashes.
//  2. Re-check under the lock to close the TOCTOU window.
func atomicSaveRulesInternal(req saveRulesRequest) (saveRulesResult, bool) {
	prev := getRulesState()

	if req.UpdateAllow && req.ExpectedAllowHash != "" &&
		req.ExpectedAllowHash != prev.AllowlistHash {
		logWithLevel("warn", "⚠️ save: allowlist conflict (hash mismatch)")
		return saveRulesResult{
			Status:  "conflict",
			Message: "Modified in another session",
		}, false
	}
	if req.UpdateDeny && req.ExpectedDenyHash != "" &&
		req.ExpectedDenyHash != prev.DenylistHash {
		logWithLevel("warn", "⚠️ save: denylist conflict (hash mismatch)")
		return saveRulesResult{
			Status:  "conflict",
			Message: "Modified in another session",
		}, false
	}

	newAllowHash := prev.AllowlistHash
	newDenyHash := prev.DenylistHash
	if req.UpdateAllow {
		newAllowHash = contentHash([]byte(req.AllowContent))
	}
	if req.UpdateDeny {
		newDenyHash = contentHash([]byte(req.DenyContent))
	}

	allowChanged := req.UpdateAllow && newAllowHash != prev.AllowlistHash
	denyChanged := req.UpdateDeny && newDenyHash != prev.DenylistHash

	if !allowChanged && !denyChanged {
		return saveRulesResult{
			Status:    "ok",
			Changed:   false,
			AllowHash: prev.AllowlistHash,
			DenyHash:  prev.DenylistHash,
			Entries:   getEntriesCount(),
		}, false
	}

	rulesStateMu.Lock()
	defer rulesStateMu.Unlock()

	if currentRules.AllowlistHash != prev.AllowlistHash ||
		currentRules.DenylistHash != prev.DenylistHash {
		logWithLevel("warn", "⚠️ save: state changed during save, aborting")
		return saveRulesResult{
			Status:  "conflict",
			Message: "Modified in another session, please retry",
		}, false
	}

	prevAllowData, _ := os.ReadFile(ALLOWLIST_FILE)
	prevDenyData, _ := os.ReadFile(DENYLIST_FILE)

	if req.UpdateAllow {
		if err := atomicWriteFile(ALLOWLIST_FILE, []byte(req.AllowContent), 0644); err != nil {
			logWithLevel("error", "❌ save: write allowlist failed: "+err.Error())
			return saveRulesResult{
				Status:  "error",
				Message: "Failed to save allowlist",
			}, false
		}
	}
	if req.UpdateDeny {
		if err := atomicWriteFile(DENYLIST_FILE, []byte(req.DenyContent), 0644); err != nil {
			logWithLevel("error", "❌ save: write denylist failed: "+err.Error())
			if req.UpdateAllow {
				restoreFile(ALLOWLIST_FILE, prevAllowData)
			}
			return saveRulesResult{
				Status:  "error",
				Message: "Failed to save denylist",
			}, false
		}
	}

	if err := rebuildBlocklist(); err != nil {
		logWithLevel("error", "❌ save: rebuild failed: "+err.Error())

		if req.UpdateAllow {
			restoreFile(ALLOWLIST_FILE, prevAllowData)
		}
		if req.UpdateDeny {
			restoreFile(DENYLIST_FILE, prevDenyData)
		}

		if err2 := rebuildBlocklist(); err2 != nil {
			logWithLevel("error", "❌ rollback rebuild failed: "+err2.Error())
		}

		return saveRulesResult{
			Status:  "error",
			Message: "Failed to rebuild blocklist",
		}, false
	}

	currentRules = rulesStateSnapshot{
		AllowlistHash: newAllowHash,
		DenylistHash:  newDenyHash,
	}

	aH, dH := newAllowHash, newDenyHash
	if len(aH) > 12 {
		aH = aH[:12]
	}
	if len(dH) > 12 {
		dH = dH[:12]
	}
	logEvent(fmt.Sprintf("✅ save applied: allow=%s deny=%s", aH, dH))

	return saveRulesResult{
		Status:    "ok",
		Changed:   true,
		AllowHash: newAllowHash,
		DenyHash:  newDenyHash,
		Entries:   getEntriesCount(),
	}, true
}

func (r saveRulesResult) toMap(primaryHash string) map[string]interface{} {
	m := map[string]interface{}{
		"status": r.Status,
	}
	if r.Message != "" {
		m["message"] = r.Message
	}
	if r.Status == "ok" {
		m["changed"] = r.Changed
		m["hash"] = primaryHash
		m["allow_hash"] = r.AllowHash
		m["deny_hash"] = r.DenyHash
		m["entries"] = r.Entries
	}
	return m
}

// restoreFile atomically restores path to data. A nil data
// removes the file.
func restoreFile(path string, data []byte) {
	if data == nil {
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			logWithLevel("warn", fmt.Sprintf("⚠️ restore: remove %s: %v", path, err))
		}
		return
	}
	if err := atomicWriteFile(path, data, 0644); err != nil {
		logWithLevel("error", fmt.Sprintf("❌ restore %s failed: %v", path, err))
	}
}

// ============================================================
// [26] Wrappers
// ============================================================
func saveAllowlist(content, expectedHash string) map[string]interface{} {
	prev := getRulesState()
	if expectedHash != "" && expectedHash != prev.AllowlistHash {
		return map[string]interface{}{
			"status":  "conflict",
			"message": "Modified in another session",
		}
	}
	newHash := contentHash([]byte(content))
	if newHash == prev.AllowlistHash {
		return map[string]interface{}{
			"status":     "ok",
			"changed":    false,
			"hash":       prev.AllowlistHash,
			"allow_hash": prev.AllowlistHash,
			"deny_hash":  prev.DenylistHash,
			"entries":    getEntriesCount(),
		}
	}
	createAutoBackup("pre-allowlist-save")
	return runAtomicSave(saveRulesRequest{
		AllowContent:      content,
		ExpectedAllowHash: expectedHash,
		UpdateAllow:       true,
	}, "allow")
}

func saveDenylist(content, expectedHash string) map[string]interface{} {
	prev := getRulesState()
	if expectedHash != "" && expectedHash != prev.DenylistHash {
		return map[string]interface{}{
			"status":  "conflict",
			"message": "Modified in another session",
		}
	}
	newHash := contentHash([]byte(content))
	if newHash == prev.DenylistHash {
		return map[string]interface{}{
			"status":     "ok",
			"changed":    false,
			"hash":       prev.DenylistHash,
			"allow_hash": prev.AllowlistHash,
			"deny_hash":  prev.DenylistHash,
			"entries":    getEntriesCount(),
		}
	}
	createAutoBackup("pre-denylist-save")
	return runAtomicSave(saveRulesRequest{
		DenyContent:      content,
		ExpectedDenyHash: expectedHash,
		UpdateDeny:       true,
	}, "deny")
}

func saveCustomRulesCombined(allow, deny string) map[string]interface{} {
	prev := getRulesState()
	allowChanged := contentHash([]byte(allow)) != prev.AllowlistHash
	denyChanged := contentHash([]byte(deny)) != prev.DenylistHash
	if !allowChanged && !denyChanged {
		return map[string]interface{}{
			"status":     "ok",
			"changed":    false,
			"hash":       prev.AllowlistHash,
			"allow_hash": prev.AllowlistHash,
			"deny_hash":  prev.DenylistHash,
			"entries":    getEntriesCount(),
		}
	}
	createAutoBackup("pre-custom-rules-save")
	return runAtomicSave(saveRulesRequest{
		AllowContent: allow,
		DenyContent:  deny,
		UpdateAllow:  true,
		UpdateDeny:   true,
	}, "allow")
}

// appendDenylist appends `content` to denylist.txt and delegates
// to saveDenylist.
//
// The expected hash comes from getRulesState() — the same
// source saveDenylist() consults — so an external edit to
// denylist.txt (e.g. by customize.sh during an upgrade) does
// not produce a spurious conflict.
func appendDenylist(content string) map[string]interface{} {
	content = strings.TrimSpace(content)
	if content == "" {
		return map[string]interface{}{
			"status":  "error",
			"message": "Missing or empty 'content' parameter",
		}
	}

	existing, err := os.ReadFile(DENYLIST_FILE)
	if err != nil && !os.IsNotExist(err) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot read denylist.txt",
		}
	}

	combined := string(existing)
	if combined != "" && !strings.HasSuffix(combined, "\n") {
		combined += "\n"
	}
	combined += content
	if !strings.HasSuffix(combined, "\n") {
		combined += "\n"
	}

	prev := getRulesState()
	result := saveDenylist(combined, prev.DenylistHash)

	if result["status"] == "ok" {
		if changed, _ := result["changed"].(bool); changed {
			entries, _ := result["entries"].(int)
			result["message"] = fmt.Sprintf("Appended and processed %d rules", entries)
		} else {
			result["message"] = "No changes detected"
		}
	}
	return result
}

// ============================================================
// [27] Profile response
// ============================================================
func buildProfileResponse() map[string]interface{} {
	data, _ := os.ReadFile(SELECTED_FILE)
	key := strings.TrimSpace(string(data))
	if key == "" {
		key = "pro"
	}
	name := key
	if p, ok := profiles[key]; ok {
		name = p.Name
	}
	entries := getEntriesCount()

	lastUpdateMu.Lock()
	if time.Since(lastUpdateTime) >= LAST_UPDATE_CACHE_TTL || lastUpdateCache == "" {
		if fi, err := os.Stat(BLOCKLIST_FILE); err == nil {
			lastUpdateCache = fi.ModTime().Format("2006-01-02 15:04:05")
		}
		lastUpdateTime = time.Now()
	}
	lastUpdateCopy := lastUpdateCache
	lastUpdateMu.Unlock()

	return map[string]interface{}{
		"key":             key,
		"name":            name,
		"entries":         entries,
		"is_empty":        entries == 0,
		"last_update":     lastUpdateCopy,
		"memory_limit_mb": memoryLimitForProfile(key) / (1024 * 1024),
	}
}

// ============================================================
// [28] Update profile
// ============================================================
// updateProfile downloads the selected profile, validates it,
// rebuilds the blocklist, restarts the engine if it was
// running, and applies the new memory limit.
func updateProfile(key string) map[string]interface{} {
	defer func() {
		if r := recover(); r != nil {
			logWithLevel("error", fmt.Sprintf("PANIC in updateProfile: %v", r))
		}
	}()
	updatingMu.Lock()
	if isUpdating {
		updatingMu.Unlock()
		return map[string]interface{}{"status": "error", "message": "⚠️ Another update in progress"}
	}
	isUpdating = true
	updatingMu.Unlock()
	defer func() {
		updatingMu.Lock()
		isUpdating = false
		updatingMu.Unlock()
	}()

	profile, ok := profiles[key]
	if !ok {
		return map[string]interface{}{"status": "error", "message": "Invalid profile"}
	}

	createAutoBackup("pre-profile-change")

	writeProgress(5, "Connecting to blocklist servers...")
	// Short delay lets the first SSE progress event reach slow
	// clients before the download begins.
	time.Sleep(1500 * time.Millisecond)

	tempFile := RAW_BLOCKLIST_FILE + ".tmp"
	defer os.Remove(tempFile)

	var err error
	retryDelays := []int{2, 4, 8}

	for attempt := 1; attempt <= DOWNLOAD_RETRIES; attempt++ {
		writeProgress(10, fmt.Sprintf("Downloading (attempt %d/%d)...", attempt, DOWNLOAD_RETRIES))
		err = downloadWithProgress(profile.URL, tempFile)
		if err == nil {
			break
		}
		if attempt < DOWNLOAD_RETRIES {
			delay := retryDelays[attempt-1]
			writeProgress(10, fmt.Sprintf("❌ Attempt %d failed, retrying...", attempt))
			time.Sleep(time.Duration(delay) * time.Second)
		}
	}
	if err != nil {
		writeProgress(0, "❌ Download failed: "+err.Error())
		return map[string]interface{}{"status": "error", "message": "Download failed", "details": err.Error()}
	}

	writeProgress(85, "Verifying downloaded data...")
	time.Sleep(1000 * time.Millisecond)
	if err := validateBlocklist(tempFile); err != nil {
		writeProgress(0, "❌ Downloaded file is corrupt or invalid")
		return map[string]interface{}{"status": "error", "message": "File corrupt", "details": err.Error()}
	}

	writeProgress(88, "Preparing base file...")
	if err := os.Rename(tempFile, RAW_BLOCKLIST_FILE); err != nil {
		src, oerr := os.Open(tempFile)
		if oerr != nil {
			writeProgress(0, "❌ Failed to open temp file")
			return map[string]interface{}{"status": "error", "message": "Failed to move file"}
		}
		streamErr := atomicWriteStream(RAW_BLOCKLIST_FILE, 0644, func(w io.Writer) error {
			_, e := io.Copy(w, src)
			return e
		})
		src.Close()
		if streamErr != nil {
			writeProgress(0, "❌ Failed to save base file")
			return map[string]interface{}{"status": "error", "message": "Failed to save base file"}
		}
	}

	writeProgress(90, "Applying custom rules...")
	time.Sleep(500 * time.Millisecond)

	serviceMutex.Lock()
	defer serviceMutex.Unlock()

	wasRunning := (getStatus() == "ON")
	if wasRunning {
		stopService()
		time.Sleep(500 * time.Millisecond)
	}

	if err := rebuildBlocklist(); err != nil {
		logWithLevel("error", "❌ updateProfile: rebuild failed: "+err.Error())
		if wasRunning {
			startService()
		}
		writeProgress(0, "❌ Failed to rebuild blocklist")
		return map[string]interface{}{"status": "error", "message": "Rebuild failed", "details": err.Error()}
	}

	atomicWriteFile(SELECTED_FILE, []byte(key), 0666)
	applyMemoryLimit(key)

	writeProgress(95, "Restarting DNSCrypt engine...")
	time.Sleep(500 * time.Millisecond)

	if wasRunning {
		startService()
	}
	time.Sleep(1500 * time.Millisecond)

	entries := getEntriesCount()

	lastUpdateMu.Lock()
	lastUpdateCache = time.Now().Format("2006-01-02 15:04:05")
	lastUpdateTime = time.Now()
	lastUpdateCopy := lastUpdateCache
	lastUpdateMu.Unlock()

	writeProgress(100, fmt.Sprintf("✅ Protection applied successfully (%d entries)", entries))
	time.Sleep(1000 * time.Millisecond)
	writeProgress(0, "")

	broadcastEvent("stats", fmt.Sprintf("{\"blocked_today\":\"%s\"}", getBlockedStats()))
	broadcastEvent("resources", fmt.Sprintf("{\"ram\":\"%s\"}", getResourceUsage()))

	runShell("ndc resolver flushdefaultif 2>/dev/null || true")
	debug.FreeOSMemory()

	return map[string]interface{}{
		"status":          "ok",
		"message":         fmt.Sprintf("Blocklist updated to %s", profile.Name),
		"entries":         entries,
		"last_update":     lastUpdateCopy,
		"memory_limit_mb": memoryLimitForProfile(key) / (1024 * 1024),
	}
}

// ============================================================
// [29] Old modules
// ============================================================
// checkOldModules returns up to MAX_OLD_MODULES_SHOW stale
// module folders (same id, different fingerprint). Cached for
// 60 seconds.
func checkOldModules() []OldModuleInfo {
	defer func() { recover() }()
	oldModulesMutex.Lock()
	defer oldModulesMutex.Unlock()
	if time.Since(oldModulesTime) < 60*time.Second && oldModulesCache != nil {
		return oldModulesCache
	}
	var oldModules []OldModuleInfo
	currentFingerprint := ""
	if data, err := os.ReadFile(filepath.Join(MODDIR, ".module.fingerprint")); err == nil {
		currentFingerprint = strings.TrimSpace(string(data))
	}
	entries, err := os.ReadDir(MODULES_DIR)
	if err != nil {
		return oldModules
	}
	count := 0
	for _, entry := range entries {
		if count >= MAX_OLD_MODULES_SHOW {
			break
		}
		if !entry.IsDir() {
			continue
		}
		modulePath := filepath.Join(MODULES_DIR, entry.Name())
		if modulePath == MODDIR {
			continue
		}
		fingerprintData, err := os.ReadFile(filepath.Join(modulePath, ".module.fingerprint"))
		if err != nil {
			continue
		}
		fingerprint := strings.TrimSpace(string(fingerprintData))
		if !strings.Contains(fingerprint, "dnscrypt-proxy-webui") || fingerprint == currentFingerprint {
			continue
		}
		info := OldModuleInfo{Path: modulePath, Name: entry.Name()}
		if propData, err := os.ReadFile(filepath.Join(modulePath, "module.prop")); err == nil {
			for _, line := range strings.Split(string(propData), "\n") {
				if strings.HasPrefix(line, "version=") {
					info.Version = strings.TrimPrefix(line, "version=")
				}
				if strings.HasPrefix(line, "id=") {
					info.ID = strings.TrimPrefix(line, "id=")
				}
			}
		}
		if _, err := os.Stat(filepath.Join(modulePath, "disable")); err == nil {
			info.Disabled = true
		}
		oldModules = append(oldModules, info)
		count++
	}
	oldModulesCache = oldModules
	oldModulesTime = time.Now()
	return oldModules
}

// removeModule safely deletes a stale module folder.
//
// Path-injection hardening (CodeQL go/path-injection):
//   - filepath.Base reduces the caller's path to its last
//     component (no separators, no "..").
//   - securejoin.SecureJoin reconstructs the full path from
//     the trusted base directory and the sanitized name.
//   - A defence-in-depth prefix check rejects paths that are
//     not directly under MODULES_DIR.
//
// A fingerprint check rejects folders that do not belong to
// this module.
func removeModule(modulePath string) map[string]interface{} {
	defer func() { recover() }()

	name := filepath.Base(modulePath)
	if name == "" || name == "." || name == ".." ||
		name == string(filepath.Separator) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Invalid module name",
		}
	}

	expectedPrefix := MODULES_DIR + string(filepath.Separator)
	if !strings.HasPrefix(filepath.Clean(modulePath), expectedPrefix) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Invalid path",
		}
	}

	cleanPath, err := securejoin.SecureJoin(MODULES_DIR, name)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "Invalid path",
		}
	}

	if cleanPath == MODDIR {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot remove current module",
		}
	}

	fingerprintPath := filepath.Join(cleanPath, ".module.fingerprint")
	fingerprintData, err := os.ReadFile(fingerprintPath)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "Module has no valid fingerprint",
		}
	}
	if !strings.Contains(string(fingerprintData), "dnscrypt-proxy-webui") {
		return map[string]interface{}{
			"status":  "error",
			"message": "This is not a DNSCrypt Proxy module",
		}
	}

	if err := os.RemoveAll(cleanPath); err != nil {
		logWithLevel("error", "❌ removeModule failed: "+err.Error())
		return map[string]interface{}{
			"status":  "error",
			"message": "Failed to remove module",
		}
	}

	oldModulesMutex.Lock()
	oldModulesCache = nil
	oldModulesTime = time.Time{}
	oldModulesMutex.Unlock()

	return map[string]interface{}{
		"status":  "ok",
		"message": "Old module removed successfully",
	}
}

// ============================================================
// [30] Log file management
// ============================================================
// Security model:
//
//   LOGS_DIR (/data/local/tmp/) is world-writable. Any local
//   process can create a symlink named like a valid log file
//   and point it at a sensitive path (e.g. proxy/webui.conf).
//   Every read path below refuses such a symlink before any
//   byte is returned, using a three-layer defence:
//
//     1. Lstat pre-check — rejects symlinks and non-regular
//        files (fifos, sockets, devices) without following them.
//     2. O_NOFOLLOW — the kernel rejects symlinks atomically
//        at open time. Even if the file is swapped between
//        Lstat and Open, the open fails with ELOOP.
//     3. SameFile post-check — compares the Lstat inode to
//        the opened file's inode. Catches a race where the
//        symlink was replaced by a different regular file
//        between check and open.
//
//   The two list/clear paths use the same three layers plus
//   an entry-type check (ReadDir exposes Lstat semantics, so
//   symlinks are skipped at scan time).
//
//   All error messages are intentionally identical for
//   "symlink rejected", "file missing", and "not a regular
//   file" — distinguishing them would leak information about
//   an attacker's setup to the WebUI.

// safeOpenRegular opens path for reading, refusing symlinks
// and non-regular files.
//
// Used by every log-file read path in this section. See the
// section header for the three-layer defence rationale.
func safeOpenRegular(path string) (*os.File, os.FileInfo, error) {
	lfi, err := os.Lstat(path)
	if err != nil {
		return nil, nil, err
	}
	if lfi.Mode()&os.ModeSymlink != 0 {
		return nil, nil, errors.New("symlink rejected")
	}
	if !lfi.Mode().IsRegular() {
		return nil, nil, errors.New("not a regular file")
	}

	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return nil, nil, err
	}

	fi, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, nil, err
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		f.Close()
		return nil, nil, errors.New("symlink rejected after open")
	}
	if !fi.Mode().IsRegular() {
		f.Close()
		return nil, nil, errors.New("not a regular file after open")
	}
	if !os.SameFile(lfi, fi) {
		f.Close()
		return nil, nil, errors.New("file changed between check and open")
	}

	return f, fi, nil
}

// sanitizeLogFileName returns a safe basename or ("", false).
// Only files starting with "dnscrypt" and ending with a known
// extension are accepted.
func sanitizeLogFileName(name string) (string, bool) {
	if name == "" || len(name) > 200 {
		return "", false
	}
	if strings.ContainsAny(name, "/\\\x00") {
		return "", false
	}
	if strings.Contains(name, "..") {
		return "", false
	}
	if !strings.HasPrefix(name, "dnscrypt") {
		return "", false
	}
	base := filepath.Base(name)
	if base != name || base == "." || base == ".." {
		return "", false
	}
	validExts := []string{".log", ".gz", ".old", ".txt"}
	for _, ext := range validExts {
		if strings.HasSuffix(base, ext) {
			return base, true
		}
	}
	if strings.Contains(base, ".emergency.") {
		return base, true
	}
	return "", false
}

func isAllowedLogFile(name string) bool {
	if name == "" || len(name) > 200 {
		return false
	}
	if strings.ContainsAny(name, "/\\\x00") {
		return false
	}
	if strings.Contains(name, "..") {
		return false
	}
	if !strings.HasPrefix(name, "dnscrypt") {
		return false
	}
	validExts := []string{".log", ".gz", ".old", ".txt"}
	for _, ext := range validExts {
		if strings.HasSuffix(name, ext) {
			return true
		}
	}
	if strings.Contains(name, ".emergency.") {
		return true
	}
	return false
}

// classifyLogFile buckets a file into one of: sensitive,
// emergency, archive, active. The WebUI groups by this label.
func classifyLogFile(name string) string {
	if strings.Contains(name, "credential") {
		return "sensitive"
	}
	if strings.Contains(name, ".emergency.") {
		return "emergency"
	}
	if strings.HasSuffix(name, ".gz") || strings.HasSuffix(name, ".old") {
		return "archive"
	}
	return "active"
}

func isSensitiveFile(name string) bool {
	return strings.Contains(name, "credential")
}

// listLogFiles returns the log files in LOGS_DIR, sorted by
// mtime descending.
//
// Symlinks and non-regular files are skipped at scan time:
// a world-writable LOGS_DIR lets a local attacker inject a
// symlink named like a log file (e.g. dnscrypt-evil.log →
// webui.conf). ReadDir exposes Lstat semantics, so entry.Type()
// already reflects the symlink — no follow-up open is needed
// here. The open path is protected separately by
// safeOpenRegular.
func listLogFiles() map[string]interface{} {
	entries, err := os.ReadDir(LOGS_DIR)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot read directory: " + err.Error(),
		}
	}

	var files []LogFileInfo
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if entry.Type()&os.ModeSymlink != 0 {
			continue
		}
		name := entry.Name()
		if !isAllowedLogFile(name) {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		if !info.Mode().IsRegular() {
			continue
		}
		files = append(files, LogFileInfo{
			Name:      name,
			Size:      info.Size(),
			MTime:     info.ModTime().Unix(),
			Type:      classifyLogFile(name),
			Extension: filepath.Ext(name),
		})
	}

	sort.Slice(files, func(i, j int) bool {
		return files[i].MTime > files[j].MTime
	})

	return map[string]interface{}{
		"status": "ok",
		"files":  files,
		"count":  len(files),
	}
}

// readLogFile returns the last LOG_MAX_READ_BYTES bytes of a
// log file, transparently decompressing .gz archives.
//
// Sensitive files require the caller to pass confirm="1".
//
// Symlink rejection: safeOpenRegular refuses symlinks and non-
// regular files before any byte is read, so a symlink injected
// into the world-writable LOGS_DIR cannot be used to read an
// arbitrary file under root privileges.
func readLogFile(name, confirm string) map[string]interface{} {
	safeName, ok := sanitizeLogFileName(name)
	if !ok {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not allowed",
		}
	}

	if isSensitiveFile(safeName) && confirm != "1" {
		return map[string]interface{}{
			"status":  "requires_confirm",
			"message": "Sensitive file requires confirmation",
			"name":    safeName,
		}
	}

	path := filepath.Join(LOGS_DIR, safeName)
	f, info, err := safeOpenRegular(path)
	if err != nil {
		// A symlink and a missing file return the same message —
		// distinguishing them would leak information about the
		// attacker's setup.
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found or not allowed",
		}
	}
	defer f.Close()

	var content string
	var truncated bool

	if strings.HasSuffix(name, ".gz") {
		gz, err := gzip.NewReader(f)
		if err != nil {
			return map[string]interface{}{
				"status":  "error",
				"message": "Decompression failed: " + err.Error(),
			}
		}
		defer gz.Close()

		limited := io.LimitReader(gz, LOG_MAX_READ_BYTES+1)
		data, _ := io.ReadAll(limited)
		if int64(len(data)) > LOG_MAX_READ_BYTES {
			data = data[:LOG_MAX_READ_BYTES]
			truncated = true
		}
		content = string(data)
	} else {
		readSize := info.Size()
		if readSize > LOG_MAX_READ_BYTES {
			truncated = true
			if _, seekErr := f.Seek(-LOG_MAX_READ_BYTES, io.SeekEnd); seekErr == nil {
				data := make([]byte, LOG_MAX_READ_BYTES)
				n, _ := io.ReadFull(f, data)
				content = string(data[:n])
			} else {
				logWithLevel("warn", "readLogFile: backward seek failed for "+name+", using slow path")
				limited := io.LimitReader(f, LOG_MAX_READ_BYTES*2)
				data, _ := io.ReadAll(limited)
				if int64(len(data)) > LOG_MAX_READ_BYTES {
					data = data[len(data)-LOG_MAX_READ_BYTES:]
				}
				content = string(data)
			}
		} else {
			data := make([]byte, readSize)
			n, _ := io.ReadFull(f, data)
			content = string(data[:n])
		}
	}

	return map[string]interface{}{
		"status":    "ok",
		"name":      name,
		"size":      info.Size(),
		"content":   content,
		"truncated": truncated,
		"type":      classifyLogFile(name),
	}
}

// clearLogFile truncates a log file. Refuses to touch the
// active system log or sensitive files.
//
// os.Truncate follows symlinks — a symlinked name would
// truncate the target (e.g. proxy/webui.conf) under root
// privileges. Opening with O_NOFOLLOW and calling
// f.Truncate(0) on the already-validated handle is race-free:
// the inode we truncate is the one we verified.
func clearLogFile(name string) map[string]interface{} {
	safeName, ok := sanitizeLogFileName(name)
	if !ok {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not allowed",
		}
	}

	if isSensitiveFile(safeName) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot clear sensitive file",
		}
	}

	if safeName == filepath.Base(LOG_FILE) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot clear the active system log",
		}
	}

	path := filepath.Join(LOGS_DIR, safeName)

	// Symlink rejection: Lstat pre-check + O_NOFOLLOW + SameFile
	// post-check — identical pattern to safeOpenRegular. The open
	// mode is O_WRONLY so we can truncate on the validated handle.
	lfi, err := os.Lstat(path)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found or not allowed",
		}
	}
	if lfi.Mode()&os.ModeSymlink != 0 || !lfi.Mode().IsRegular() {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found or not allowed",
		}
	}

	f, err := os.OpenFile(path, os.O_WRONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found or not allowed",
		}
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil || !os.SameFile(lfi, fi) {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found or not allowed",
		}
	}

	if err := f.Truncate(0); err != nil {
		logWithLevel("error", "❌ clearLogFile failed for "+safeName+": "+err.Error())
		return map[string]interface{}{
			"status":  "error",
			"message": "Failed to clear file",
		}
	}

	logEvent("🗑️ Cleared log file: " + safeName)
	return map[string]interface{}{
		"status":  "ok",
		"message": "File cleared successfully",
	}
}

// handleDownloadLog streams a log file to the client as an
// attachment.
//
// Symlink rejection: safeOpenRegular refuses symlinks and non-
// regular files before any byte is sent. Combined with the
// max-size check on the validated handle, a symlink injected
// into LOGS_DIR cannot be used to exfiltrate an arbitrary file.
func handleDownloadLog(w http.ResponseWriter, r *http.Request) {
	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		fmt.Fprint(w, "Unauthorized")
		return
	}

	name := r.URL.Query().Get("file")
	safeName, ok := sanitizeLogFileName(name)
	if !ok {
		w.WriteHeader(http.StatusForbidden)
		fmt.Fprint(w, "Forbidden")
		return
	}

	if isSensitiveFile(safeName) && r.URL.Query().Get("confirm") != "1" {
		w.WriteHeader(http.StatusForbidden)
		fmt.Fprint(w, "Confirmation required")
		return
	}

	path := filepath.Join(LOGS_DIR, safeName)
	f, info, err := safeOpenRegular(path)
	if err != nil {
		// Symlink and missing file both return 404 — a distinct
		// error would leak information about the attacker's
		// setup.
		http.NotFound(w, r)
		return
	}
	defer f.Close()

	if info.Size() > LOG_MAX_DOWNLOAD_BYTES {
		w.WriteHeader(http.StatusRequestEntityTooLarge)
		fmt.Fprint(w, "File too large")
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, safeName))
	w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	io.Copy(w, f)
}

// ============================================================
// [31] runtime_info
// ============================================================
// buildBackupInfo scans PERSISTENT_BACKUP and returns the
// seven-field backups object exposed by /api?action=runtime_info.
//
// Snapshot detection is manifest-based: a directory is a
// snapshot iff it contains a .manifest.json file. current/,
// txn-*, orphan-txn-* are excluded by name.
//
// last_backup_name is selected by mtime (descending), not by
// lexicographic name — robust against clock drift.
func buildBackupInfo() map[string]interface{} {
	info := map[string]interface{}{
		"available":        0,
		"in_flight_txn":    0,
		"orphan_txn":       0,
		"last_backup":      nil,
		"last_backup_name": nil,
		"last_stable":      nil,
		"path":             PERSISTENT_BACKUP,
	}

	entries, err := os.ReadDir(PERSISTENT_BACKUP)
	if err != nil {
		return info
	}

	var snapshots []os.DirEntry
	inFlightTxn := 0
	orphanTxn := 0

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()

		if name == "current" {
			continue
		}
		if strings.HasPrefix(name, "txn-") {
			inFlightTxn++
			continue
		}
		if strings.HasPrefix(name, "orphan-txn-") {
			orphanTxn++
			continue
		}

		manifestPath := filepath.Join(PERSISTENT_BACKUP, name, ".manifest.json")
		if _, err := os.Stat(manifestPath); err != nil {
			continue
		}

		snapshots = append(snapshots, e)
	}

	info["available"] = len(snapshots)
	info["in_flight_txn"] = inFlightTxn
	info["orphan_txn"] = orphanTxn

	if len(snapshots) > 0 {
		sort.Slice(snapshots, func(i, j int) bool {
			fi, errI := snapshots[i].Info()
			fj, errJ := snapshots[j].Info()
			if errI != nil || errJ != nil {
				return snapshots[i].Name() < snapshots[j].Name()
			}
			return fi.ModTime().Before(fj.ModTime())
		})
		newest := snapshots[len(snapshots)-1]
		info["last_backup_name"] = newest.Name()

		if fi, err := newest.Info(); err == nil {
			info["last_backup"] = fi.ModTime().Format("2006-01-02 15:04:05")
		}
	}

	if data, err := os.ReadFile(LAST_STABLE_FILE); err == nil {
		ls := strings.TrimSpace(string(data))
		if ls != "" {
			info["last_stable"] = ls
		}
	}

	return info
}

// buildRuntimeInfo returns the /api?action=runtime_info payload.
//
// profile_key and memory_limit_mb are derived from the SAME
// source (fileProfile, freshly read from selected_profile.txt).
// This guarantees consistency even in the edge case where the
// file was edited externally (without going through
// updateProfile()) and main.go has not yet re-applied the
// memory limit.
func buildRuntimeInfo() map[string]interface{} {
	fileProfile := readSelectedProfile()

	info := map[string]interface{}{
		"version":       BuildVersion,
		"commit":        BuildCommit,
		"build_time":    BuildTime,
		"project_url":   ProjectURL,
		"app_version":   readAppVersion(),
		"run_dir":       getActiveRunDir(),
		"status_file":   STATUS_FILE,
		"pid_file":      PID_FILE,
		"progress_file": PROGRESS_FILE,
		"log_file":      LOG_FILE,
		"bind_addr":     getBindAddr(),

		"webui_port":     getWebUIPort(),
		"dashboard_port": getDashboardPort(),

		"memory_limit_mb": memoryLimitForProfile(fileProfile) / (1024 * 1024),
		"profile_key":     fileProfile,

		"backups": buildBackupInfo(),
	}

	if ts, err := strconv.ParseInt(BuildTime, 10, 64); err == nil && ts > 0 {
		info["build_time_human"] = time.Unix(ts, 0).UTC().Format(time.RFC3339)
	}

	return info
}

func handleRuntimeInfo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Unauthorized"})
		return
	}

	json.NewEncoder(w).Encode(buildRuntimeInfo())
}

// ============================================================
// [31b] /healthz and /readyz
// ============================================================
func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

// handleReadyz is a detailed readiness probe. Localhost-only.
// Reports: config, blocklist, run_dir, dns_engine (running +
// port), version.
func handleReadyz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")

	if !isLocalRequest(r) {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "readyz is localhost-only",
		})
		return
	}

	checks := map[string]string{}
	healthy := true

	if _, err := os.Stat(CONF); err != nil {
		checks["config"] = "missing"
		healthy = false
	} else {
		checks["config"] = "ok"
	}

	if _, err := os.Stat(BLOCKLIST_FILE); err != nil && !os.IsNotExist(err) {
		checks["blocklist"] = "unreadable"
		healthy = false
	} else {
		checks["blocklist"] = "ok"
	}

	if !isRunDirUsable() {
		checks["run_dir"] = "unusable"
		healthy = false
	} else {
		checks["run_dir"] = "ok"
	}

	if _, found := isProcessRunning(); !found {
		checks["dns_engine"] = "not_running"
		healthy = false
	} else if !isPortOpenCached(5354) {
		checks["dns_engine"] = "port_closed"
		healthy = false
	} else {
		checks["dns_engine"] = "ok"
	}

	checks["version"] = BuildVersion

	if !healthy {
		w.WriteHeader(http.StatusServiceUnavailable)
		checks["status"] = "unhealthy"
	} else {
		w.WriteHeader(http.StatusOK)
		checks["status"] = "ready"
	}

	json.NewEncoder(w).Encode(checks)
}

// ============================================================
// [32] API handler
// ============================================================
// hasEndpoint does an EXACT path match against /api/<name> or
// /api/<name>/. Used by both checkAuth() and the apiHandler
// dispatch tree — no prefix/substring ambiguity.
func hasEndpoint(path, name string) bool {
	if path == "/api/"+name {
		return true
	}
	if path == "/api/"+name+"/" {
		return true
	}
	return false
}

// apiHandler is a stateless dispatcher for the /api endpoints.
// Each method handles exactly one endpoint. No fields — the
// handler holds no per-request state.
type apiHandler struct{}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSONErrorWithHint(w, status, message, "")
}

// writeJSONErrorWithHint is writeJSONError with an optional
// "hint" field.
func writeJSONErrorWithHint(w http.ResponseWriter, status int, message, hint string) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.WriteHeader(status)
	m := map[string]string{
		"status":  "error",
		"message": message,
	}
	if hint != "" {
		m["hint"] = hint
	}
	json.NewEncoder(w).Encode(m)
}

// requireFormContentType rejects requests whose Content-Type is
// neither form-urlencoded nor multipart/form-data. Prevents a
// JSON body from being silently accepted as empty.
//
// An empty Content-Type is accepted — some clients (including
// wget --post-data=”) omit it, and FormValue still parses the
// body correctly in that case.
func requireFormContentType(w http.ResponseWriter, r *http.Request) bool {
	ct := r.Header.Get("Content-Type")
	if ct == "" {
		return true
	}
	if strings.HasPrefix(ct, "application/x-www-form-urlencoded") ||
		strings.HasPrefix(ct, "multipart/form-data") {
		return true
	}
	writeJSONError(w, http.StatusUnsupportedMediaType,
		"Content-Type must be application/x-www-form-urlencoded or multipart/form-data")
	return false
}

// writeInstallError emits a JSON error for the companion-install
// endpoints with a proper HTTP status code.
//
// The success path and the "install failed but request was
// well-formed" path still return HTTP 200. Only auth / rate-
// limit / locality failures use a non-200 status.
func writeInstallError(w http.ResponseWriter, status int, action, reason, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "error",
		"action":  action,
		"reason":  reason,
		"message": message,
	})
}

// classifyInstallResult derives the HTTP status code for a
// companion-install result:
//
//   - status=ok                             → HTTP 200
//   - status=error, reason=rate_limited     → HTTP 429
//   - status=error, reason=invalid_token    → HTTP 401
//   - status=error, reason=script_not_found → HTTP 500
//   - status=error, reason=invalid_mode     → HTTP 500
//   - status=error, reason=no_json_output   → HTTP 500
//   - status=error, any other reason        → HTTP 200
//
// The three "server is broken" reasons map to 500 so a client
// can distinguish "your install failed" from "the module is
// corrupted" with a single status-code check.
func classifyInstallResult(result map[string]interface{}) int {
	if result == nil {
		return http.StatusOK
	}
	status, _ := result["status"].(string)
	if status == "ok" {
		return http.StatusOK
	}
	reason, _ := result["reason"].(string)
	switch reason {
	case "rate_limited":
		return http.StatusTooManyRequests
	case "invalid_token":
		return http.StatusUnauthorized
	case "script_not_found", "invalid_mode", "no_json_output":
		return http.StatusInternalServerError
	}
	return http.StatusOK
}

// handleAPI is a thin router; each endpoint is a named method.
//
// Request ordering:
//  1. OPTIONS short-circuit
//  2. auth/login (POST-only)
//  3. auth/logout (POST-only, BEFORE checkAuth)
//  4. install localhost gate (before checkAuth)
//  5. checkAuth
//  6. Method dispatch (explicit switch — 405 for unsupported)
//  7. MaxBytesReader (POST only)
//
// The install localhost gate covers all three install-family
// surfaces: POST install_companion_app, POST
// uninstall_companion_app, and GET ?action=install_token. The
// token endpoint is a GET (query-string form) and is not
// caught by hasEndpoint(), so the check inspects the query
// parameter directly. Issuing a token to a non-loopback client
// would expose the install capability to the LAN even though
// the install endpoint itself remains gated — closing the
// token issuance path is the correct defence-in-depth.
func handleAPI(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if rec := recover(); rec != nil {
			logWithLevel("error", fmt.Sprintf("PANIC in handleAPI: %v", rec))
			writeJSONError(w, http.StatusInternalServerError, "Internal server error")
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	if r.Method == http.MethodOptions {
		w.Header().Set("Allow", "GET, HEAD, POST, OPTIONS")
		w.WriteHeader(http.StatusNoContent)
		return
	}

	h := &apiHandler{}

	if hasEndpoint(r.URL.Path, "auth/login") {
		h.routeAuthLogin(w, r)
		return
	}

	// auth/logout deliberately runs BEFORE checkAuth — logout
	// must work even when the session cookie is stale. The
	// handler only destroys the caller's OWN session.
	if hasEndpoint(r.URL.Path, "auth/logout") {
		h.routeAuthLogout(w, r)
		return
	}

	// Companion install family gate — loopback only.
	//
	// Covers the two POST endpoints by path, and the GET
	// token endpoint by query-string. Runs BEFORE checkAuth
	// so a non-local request gets a clean 403 regardless of
	// session state.
	isInstallPost := r.Method == http.MethodPost &&
		(hasEndpoint(r.URL.Path, "install_companion_app") ||
			hasEndpoint(r.URL.Path, "uninstall_companion_app"))
	isInstallTokenGet := r.Method == http.MethodGet &&
		r.URL.Query().Get("action") == "install_token"

	if isInstallPost || isInstallTokenGet {
		if !isLocalRequest(r) {
			action := "install"
			if hasEndpoint(r.URL.Path, "uninstall_companion_app") {
				action = "uninstall"
			} else if isInstallTokenGet {
				action = "install_token"
			}
			writeInstallError(w, http.StatusForbidden, action,
				"not_localhost", "Forbidden: install is localhost-only")
			return
		}
	}

	if !checkAuth(r) {
		writeJSONError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	switch r.Method {
	case http.MethodGet, http.MethodHead:
		h.dispatchGet(w, r)

	case http.MethodPost:
		r.Body = http.MaxBytesReader(w, r.Body, MAX_POST_BODY_SIZE)
		h.dispatchPost(w, r)

	default:
		w.Header().Set("Allow", "GET, HEAD, POST, OPTIONS")
		writeJSONError(w, http.StatusMethodNotAllowed,
			"Method not allowed: "+r.Method)
	}
}

// routeAuthLogin handles POST /api/auth/login.
func (h *apiHandler) routeAuthLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		writeJSONError(w, http.StatusMethodNotAllowed,
			"Login requires POST (CSRF protection)")
		return
	}
	handleLogin(w, r)
}

// routeAuthLogout handles POST /api/auth/logout.
func (h *apiHandler) routeAuthLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		writeJSONErrorWithHint(w, http.StatusMethodNotAllowed,
			"Logout requires POST (CSRF protection)",
			"POST /api/auth/logout")
		return
	}
	if cookie, err := r.Cookie(SESSION_COOKIE_NAME); err == nil {
		destroySession(cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     SESSION_COOKIE_NAME,
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		Secure:   isSecureCookie(),
		SameSite: http.SameSiteLaxMode,
	})
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// rejectNonLocalInstall is retained for documentation symmetry
// but is no longer invoked — the install-family gate in
// handleAPI covers all three endpoints inline.
//
// (Unused; retained to keep the diff to a minimum in case a
// future refactor reintroduces the per-endpoint gate.)
func (h *apiHandler) rejectNonLocalInstall(w http.ResponseWriter, r *http.Request) {
	action := "install"
	if hasEndpoint(r.URL.Path, "uninstall_companion_app") {
		action = "uninstall"
	}
	logWithLevel("warn", "❌ "+action+"_companion_app rejected: non-localhost request")
	writeInstallError(w, http.StatusForbidden, action,
		"not_localhost", "Forbidden: install is localhost-only")
}

// ------------------------------------------------------------
// POST dispatch
// ------------------------------------------------------------
func (h *apiHandler) dispatchPost(w http.ResponseWriter, r *http.Request) {
	switch {
	case hasEndpoint(r.URL.Path, "update_profile"):
		h.postUpdateProfile(w, r)
	case hasEndpoint(r.URL.Path, "save_allowlist"):
		h.postSaveAllowlist(w, r)
	case hasEndpoint(r.URL.Path, "save_denylist"):
		h.postSaveDenylist(w, r)
	case hasEndpoint(r.URL.Path, "save_custom_rules"):
		h.postSaveCustomRules(w, r)
	case hasEndpoint(r.URL.Path, "append_denylist"):
		h.postAppendDenylist(w, r)
	case hasEndpoint(r.URL.Path, "remove_module"):
		h.postRemoveModule(w, r)
	case hasEndpoint(r.URL.Path, "clear_log_file"):
		h.postClearLogFile(w, r)
	case hasEndpoint(r.URL.Path, "clear_logs"):
		h.postClearLogs(w, r)
	case hasEndpoint(r.URL.Path, "toggle_service"):
		h.postToggleService(w, r)
	case hasEndpoint(r.URL.Path, "restart_service"):
		h.postRestartService(w, r)
	case hasEndpoint(r.URL.Path, "ensure_running_service"):
		h.postEnsureRunningService(w, r)
	case hasEndpoint(r.URL.Path, "install_companion_app"):
		h.postInstallCompanionApp(w, r)
	case hasEndpoint(r.URL.Path, "uninstall_companion_app"):
		h.postUninstallCompanionApp(w, r)
	default:
		writeJSONError(w, http.StatusNotFound, "Unsupported POST endpoint")
	}
}

// ------------------------------------------------------------
// POST endpoint handlers
// ------------------------------------------------------------

func (h *apiHandler) postUpdateProfile(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	profile := r.FormValue("profile")
	if profile == "" {
		profile = "pro"
	}
	go updateProfile(profile)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "processing",
		"message": "Update in progress...",
	})
}

func (h *apiHandler) postSaveAllowlist(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	content := r.FormValue("allowlist")
	expectedHash := r.FormValue("expected_hash")
	result := saveAllowlist(content, expectedHash)
	if result["status"] == "conflict" {
		w.WriteHeader(http.StatusConflict)
	}
	json.NewEncoder(w).Encode(result)
}

func (h *apiHandler) postSaveDenylist(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	content := r.FormValue("denylist")
	expectedHash := r.FormValue("expected_hash")
	result := saveDenylist(content, expectedHash)
	if result["status"] == "conflict" {
		w.WriteHeader(http.StatusConflict)
	}
	json.NewEncoder(w).Encode(result)
}

func (h *apiHandler) postSaveCustomRules(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	allow := r.FormValue("allowlist")
	deny := r.FormValue("denylist")
	result := saveCustomRulesCombined(allow, deny)
	if result["status"] == "conflict" {
		w.WriteHeader(http.StatusConflict)
	}
	json.NewEncoder(w).Encode(result)
}

func (h *apiHandler) postAppendDenylist(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	content := r.FormValue("content")
	result := appendDenylist(content)
	json.NewEncoder(w).Encode(result)
}

// postRemoveModule accepts a `path` form field. The form
// content-type is enforced here for consistency with the other
// POST endpoints.
func (h *apiHandler) postRemoveModule(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	json.NewEncoder(w).Encode(removeModule(r.FormValue("path")))
}

func (h *apiHandler) postClearLogFile(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	name := r.FormValue("file")
	result := clearLogFile(name)
	json.NewEncoder(w).Encode(result)
}

// postClearLogs truncates the active system log.
//
// logMutex is acquired around the truncate so it cannot race
// with a concurrent writeLocked from the same process.
func (h *apiHandler) postClearLogs(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}

	logMutex.Lock()
	err := os.Truncate(LOG_FILE, 0)
	logMutex.Unlock()

	if err != nil {
		logWithLevel("error", "❌ clear_logs failed: "+err.Error())
		writeJSONError(w, http.StatusInternalServerError,
			"Failed to truncate log file: "+err.Error())
		return
	}
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"message": "Logs cleared successfully",
	})
}

func (h *apiHandler) postToggleService(w http.ResponseWriter, r *http.Request) {
	if !serviceMutex.TryLock() {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "error",
			"message": "Service is busy",
		})
		return
	}
	defer serviceMutex.Unlock()

	currentStatus := getStatus()
	if currentStatus == "ON" {
		stopService()
		time.Sleep(300 * time.Millisecond)
	} else {
		startService()
		time.Sleep(500 * time.Millisecond)
	}
	invalidateStatusCache()
	newStatus := getStatus()
	if newStatus == "OFF" && currentStatus == "OFF" {
		time.Sleep(2 * time.Second)
		invalidateStatusCache()
		newStatus = getStatus()
	}
	broadcastEvent("status", newStatus)
	broadcastEvent("resources", fmt.Sprintf("{\"ram\":\"%s\"}", getResourceUsage()))
	json.NewEncoder(w).Encode(map[string]interface{}{"status": newStatus})
}

func (h *apiHandler) postRestartService(w http.ResponseWriter, r *http.Request) {
	if !serviceMutex.TryLock() {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "error",
			"message": "Service is busy",
		})
		return
	}
	defer serviceMutex.Unlock()
	restartService()
	time.Sleep(500 * time.Millisecond)
	invalidateStatusCache()
	newStatus := getStatus()
	broadcastEvent("status", newStatus)
	broadcastEvent("resources", fmt.Sprintf("{\"ram\":\"%s\"}", getResourceUsage()))
	json.NewEncoder(w).Encode(map[string]interface{}{"status": newStatus})
}

// postEnsureRunningService is called by the Watchdog to restart
// the DNS engine after a crash. Respects the user's STATUS_FILE
// intent (OFF ⇒ skip).
func (h *apiHandler) postEnsureRunningService(w http.ResponseWriter, r *http.Request) {
	statusData, _ := os.ReadFile(STATUS_FILE)
	userIntent := strings.TrimSpace(string(statusData))
	if userIntent == "" {
		userIntent = "OFF"
	}
	if userIntent != "ON" {
		logEvent("ℹ️ ensure_running: user stopped the service, skipping")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  getStatus(),
			"action":  "skipped",
			"message": "User stopped the service",
		})
		return
	}
	if getStatus() == "ON" {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "ON",
			"action":  "none",
			"message": "Already running",
		})
		return
	}
	if !serviceMutex.TryLock() {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "error",
			"action":  "busy",
			"message": "Service busy",
		})
		return
	}
	defer serviceMutex.Unlock()
	logEvent("🔁 ensure_running: restarting crashed DNS (user wants ON)")
	startService()
	time.Sleep(500 * time.Millisecond)
	invalidateStatusCache()
	broadcastEvent("status", getStatus())
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": getStatus(),
		"action": "started",
	})
}

// postInstallCompanionApp — companion app one-tap install.
//
// HTTP status: 200 for success OR legitimate install failure;
// 401/429 for token/rate-limit failures; 500 for server-side
// misconfiguration. See classifyInstallResult for the full map.
func (h *apiHandler) postInstallCompanionApp(w http.ResponseWriter, r *http.Request) {
	if !requireFormContentType(w, r) {
		return
	}
	result := installCompanionApp(r)
	status := classifyInstallResult(result)
	if status != http.StatusOK {
		w.WriteHeader(status)
	}
	json.NewEncoder(w).Encode(result)
}

// postUninstallCompanionApp — companion app uninstall.
func (h *apiHandler) postUninstallCompanionApp(w http.ResponseWriter, r *http.Request) {
	result := uninstallCompanionApp()
	status := classifyInstallResult(result)
	if status != http.StatusOK {
		w.WriteHeader(status)
	}
	json.NewEncoder(w).Encode(result)
}

// ------------------------------------------------------------
// GET dispatch
// ------------------------------------------------------------
func (h *apiHandler) dispatchGet(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")

	switch action {
	case "status":
		json.NewEncoder(w).Encode(h.getStatusAction(r))

	case "get_profile":
		json.NewEncoder(w).Encode(h.getProfileAction(r))

	case "get_custom_rules":
		json.NewEncoder(w).Encode(h.getCustomRulesAction(r))

	case "get_rules_state":
		json.NewEncoder(w).Encode(h.getRulesStateAction(r))

	case "stats":
		json.NewEncoder(w).Encode(h.getStatsAction(r))

	case "resources":
		json.NewEncoder(w).Encode(h.getResourcesAction(r))

	case "runtime_info":
		json.NewEncoder(w).Encode(h.getRuntimeInfoAction(r))

	case "logs":
		json.NewEncoder(w).Encode(h.getLogsAction(r))

	case "list_logs":
		json.NewEncoder(w).Encode(h.getListLogsAction(r))

	case "read_log":
		json.NewEncoder(w).Encode(h.getReadLogAction(r))

	case "get_progress":
		json.NewEncoder(w).Encode(h.getProgressAction(r))

	case "check_old_modules":
		json.NewEncoder(w).Encode(h.getCheckOldModulesAction(r))

	case "companion_app_state":
		json.NewEncoder(w).Encode(h.getCompanionAppStateAction(r))

	case "install_token":
		json.NewEncoder(w).Encode(h.getInstallTokenAction(r))

	case "toggle", "restart", "ensure_running":
		w.Header().Set("Allow", "POST")
		writeJSONErrorWithHint(w, http.StatusMethodNotAllowed,
			"This endpoint requires POST (CSRF-GET protection)",
			fmt.Sprintf("Use POST /api/%s_service", action))

	case "":
		writeJSONErrorWithHint(w, http.StatusNotFound,
			"missing 'action' parameter",
			"Use GET /api?action=<name>")

	default:
		writeJSONError(w, http.StatusNotFound,
			fmt.Sprintf("unknown action: %q", action))
	}
}

// ------------------------------------------------------------
// GET endpoint handlers
// ------------------------------------------------------------

func (h *apiHandler) getStatusAction(r *http.Request) map[string]interface{} {
	return map[string]interface{}{"status": getStatus()}
}

func (h *apiHandler) getProfileAction(r *http.Request) map[string]interface{} {
	return buildProfileResponse()
}

func (h *apiHandler) getCustomRulesAction(r *http.Request) map[string]interface{} {
	allow, _ := os.ReadFile(ALLOWLIST_FILE)
	deny, _ := os.ReadFile(DENYLIST_FILE)
	return map[string]interface{}{
		"allowlist": string(allow),
		"denylist":  string(deny),
	}
}

func (h *apiHandler) getRulesStateAction(r *http.Request) map[string]interface{} {
	s := getRulesState()
	return map[string]interface{}{
		"allowlist_hash": s.AllowlistHash,
		"denylist_hash":  s.DenylistHash,
	}
}

func (h *apiHandler) getStatsAction(r *http.Request) map[string]interface{} {
	return map[string]interface{}{"blocked_today": getBlockedStats()}
}

func (h *apiHandler) getResourcesAction(r *http.Request) map[string]interface{} {
	return map[string]interface{}{"ram": getResourceUsage()}
}

func (h *apiHandler) getRuntimeInfoAction(r *http.Request) map[string]interface{} {
	return buildRuntimeInfo()
}

// getLogsAction returns the last MAX_LOG_LINES lines of the
// active system log. Reads only the tail 8 KB.
func (h *apiHandler) getLogsAction(r *http.Request) map[string]interface{} {
	content := ""
	if f, err := os.Open(LOG_FILE); err == nil {
		defer f.Close()
		if stat, err := f.Stat(); err == nil {
			offset := int64(8192)
			if stat.Size() < offset {
				offset = stat.Size()
			}
			if offset > 0 {
				f.Seek(stat.Size()-offset, 0)
				buf := make([]byte, offset)
				n, _ := f.Read(buf)
				text := string(buf[:n])
				if stat.Size() >= offset {
					if idx := strings.Index(text, "\n"); idx != -1 && len(text) > idx+1 {
						text = text[idx+1:]
					}
				}
				lines := strings.Split(text, "\n")
				if len(lines) > MAX_LOG_LINES {
					lines = lines[len(lines)-MAX_LOG_LINES:]
				}
				content = strings.Join(lines, "\n")
			}
		}
	}
	return map[string]interface{}{"logs": content}
}

func (h *apiHandler) getListLogsAction(r *http.Request) map[string]interface{} {
	return listLogFiles()
}

func (h *apiHandler) getReadLogAction(r *http.Request) map[string]interface{} {
	name := r.URL.Query().Get("file")
	confirm := r.URL.Query().Get("confirm")
	return readLogFile(name, confirm)
}

func (h *apiHandler) getProgressAction(r *http.Request) map[string]interface{} {
	d, _ := os.ReadFile(PROGRESS_FILE)
	progress := "0|"
	if len(d) > 0 {
		progress = strings.TrimSpace(string(d))
	}
	return map[string]interface{}{"progress": progress}
}

func (h *apiHandler) getCheckOldModulesAction(r *http.Request) map[string]interface{} {
	old := checkOldModules()
	return map[string]interface{}{"modules": old, "count": len(old)}
}

func (h *apiHandler) getCompanionAppStateAction(r *http.Request) map[string]interface{} {
	return getCompanionState()
}

func (h *apiHandler) getInstallTokenAction(r *http.Request) map[string]interface{} {
	tok := generateInstallToken()
	return map[string]interface{}{
		"token": tok,
		"ttl":   int(INSTALL_TOKEN_TTL.Seconds()),
	}
}

// ============================================================
// [33] Login handler
// ============================================================
// handleLogin accepts JSON or form-urlencoded credentials.
// Per-IP rate limited: MAX_LOGIN_ATTEMPTS / LOGIN_LOCKOUT_PERIOD.
//
// The username is sanitized before being written to the log:
// it arrives from the client and could contain newlines or
// control characters that would corrupt a single-line log
// entry (log injection).
func handleLogin(w http.ResponseWriter, r *http.Request) {
	ip := getClientIP(r)

	if isLockedOut(ip) {
		w.WriteHeader(http.StatusTooManyRequests)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Too many attempts. Try again later."})
		return
	}

	var username, password string
	contentType := r.Header.Get("Content-Type")
	if strings.Contains(contentType, "application/json") {
		r.Body = http.MaxBytesReader(w, r.Body, MAX_POST_BODY_SIZE)
		var creds struct{ Username, Password string }
		if err := json.NewDecoder(r.Body).Decode(&creds); err == nil {
			username = creds.Username
			password = creds.Password
		}
	} else {
		r.Body = http.MaxBytesReader(w, r.Body, MAX_POST_BODY_SIZE)
		username = r.FormValue("username")
		password = r.FormValue("password")
	}

	expectedUser, expectedPass := getMonitoringAuth()
	if expectedUser == "" && expectedPass == "" {
		recordLoginAttempt(ip, true)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":  "ok",
			"message": "No auth required",
			"profile": buildProfileResponse(),
		})
		return
	}

	userMatch := subtle.ConstantTimeCompare([]byte(username), []byte(expectedUser)) == 1
	passMatch := subtle.ConstantTimeCompare([]byte(password), []byte(expectedPass)) == 1

	if !userMatch || !passMatch {
		recordLoginAttempt(ip, false)
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Invalid credentials"})
		return
	}

	recordLoginAttempt(ip, true)
	token := createSession(username)
	if token == "" {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Failed to create session"})
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     SESSION_COOKIE_NAME,
		Value:    token,
		Path:     "/",
		MaxAge:   int(SESSION_TTL.Seconds()),
		HttpOnly: true,
		Secure:   isSecureCookie(),
		SameSite: http.SameSiteLaxMode,
	})

	logEvent("🔐 User '" + sanitizeLogText(username) + "' logged in from " + sanitizeLogText(ip))

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "ok",
		"message": "Login successful",
		"profile": buildProfileResponse(),
	})
}

// ============================================================
// [34] Security headers
// ============================================================
func setSecurityHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Security-Policy",
		"default-src 'self'; "+
			"script-src 'self' 'unsafe-inline'; "+
			"style-src 'self' 'unsafe-inline'; "+
			"img-src 'self' data: blob:; "+
			"font-src 'self' data:; "+
			"connect-src 'self'; "+
			"frame-ancestors 'none'; "+
			"base-uri 'self'; "+
			"form-action 'self'; "+
			"object-src 'none'")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=(), payment=()")
	w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
	w.Header().Set("Cross-Origin-Resource-Policy", "same-origin")
}

// serveFile writes a static file with the correct Content-Type
// and per-extension Cache-Control.
func serveFile(w http.ResponseWriter, r *http.Request, path, contentType string) {
	setSecurityHeaders(w)
	if strings.HasSuffix(path, ".apk") {
		w.Header().Set("Cache-Control", "public, max-age=3600, immutable")
	} else {
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	}
	if contentType != "" {
		w.Header().Set("Content-Type", contentType)
	}
	if _, err := os.Stat(path); err != nil {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, path)
}

func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		setSecurityHeaders(w)
		next.ServeHTTP(w, r)
	})
}

// ============================================================
// [35] serveStaticAssets
// ============================================================
// Registers the module's static files on the given mux, plus a
// catch-all that serves defaultFile for unknown paths.
func serveStaticAssets(mux *http.ServeMux, defaultFile string, contentType string) {
	staticAssets := map[string]struct {
		path        string
		contentType string
	}{
		"/sw.js": {
			path:        SW_FILE,
			contentType: "application/javascript; charset=utf-8",
		},
		"/manifest.json": {
			path:        MANIFEST_FILE,
			contentType: "application/json; charset=utf-8",
		},
		"/icon-192.svg": {
			path:        ICON_192_SVG_FILE,
			contentType: "image/svg+xml",
		},
		"/icon-512.svg": {
			path:        ICON_512_SVG_FILE,
			contentType: "image/svg+xml",
		},
		"/icon-192.png": {
			path:        ICON_192_PNG_FILE,
			contentType: "image/png",
		},
		"/icon-512.png": {
			path:        ICON_512_PNG_FILE,
			contentType: "image/png",
		},
		"/apple-touch-icon.png": {
			path:        APPLE_TOUCH_FILE,
			contentType: "image/png",
		},
		"/favicon-32x32.png": {
			path:        FAVICON_32_FILE,
			contentType: "image/png",
		},
		"/favicon-16x16.png": {
			path:        FAVICON_16_FILE,
			contentType: "image/png",
		},
		"/favicon.ico": {
			path:        FAVICON_ICO_FILE,
			contentType: "image/x-icon",
		},
		"/offline.html": {
			path:        OFFLINE_FILE,
			contentType: "text/html; charset=utf-8",
		},
		// Companion Android app APK (optional). Returns 404
		// when absent (dev build without the release stage).
		"/app-debug.apk": {
			path:        APK_FILE,
			contentType: "application/vnd.android.package-archive",
		},
	}

	for urlPath, asset := range staticAssets {
		p := asset.path
		ct := asset.contentType
		mux.HandleFunc(urlPath, func(w http.ResponseWriter, r *http.Request) {
			serveFile(w, r, p, ct)
		})
	}

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		serveFile(w, r, defaultFile, contentType)
	})
}

// ============================================================
// [36] Metrics proxy handler
// ============================================================
// parsePrometheus extracts numeric values from a Prometheus
// exposition. Label sets are stripped from the metric name.
func parsePrometheus(text string) map[string]float64 {
	result := make(map[string]float64)
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := fields[0]
		if idx := strings.IndexByte(name, '{'); idx > 0 {
			name = name[:idx]
		}
		val, err := strconv.ParseFloat(fields[1], 64)
		if err != nil {
			continue
		}
		result[name] += val
	}
	return result
}

// findMetric returns the first present metric from a list of
// candidate names.
func findMetric(prom map[string]float64, names ...string) float64 {
	for _, name := range names {
		if v, ok := prom[name]; ok {
			return v
		}
	}
	return 0
}

// buildDashboardJSON converts a Prometheus snapshot into the
// Dashboard's JSON schema. Missing metrics default to 0.
func buildDashboardJSON(prom map[string]float64) map[string]interface{} {
	totalQ := findMetric(prom,
		"dnscrypt_proxy_query_total",
		"dnscrypt_query_total",
		"dnscrypt_proxy_queries_total",
	)
	blockedQ := findMetric(prom,
		"dnscrypt_proxy_blocked_query_total",
		"dnscrypt_blocked_query_total",
		"dnscrypt_proxy_blocked_queries_total",
	)
	cacheHits := findMetric(prom,
		"dnscrypt_proxy_cache_hits_total",
		"dnscrypt_proxy_cache_hit_total",
		"dnscrypt_cache_hits_total",
	)
	cacheMisses := findMetric(prom,
		"dnscrypt_proxy_cache_misses_total",
		"dnscrypt_proxy_cache_miss_total",
		"dnscrypt_cache_misses_total",
	)

	hitRatio := 0.0
	if total := cacheHits + cacheMisses; total > 0 {
		hitRatio = cacheHits / total
	}

	return map[string]interface{}{
		"generated_at":       time.Now().UTC().Format(time.RFC3339),
		"total_queries":      totalQ,
		"blocked_queries":    blockedQ,
		"queries_per_second": 0,
		"uptime_seconds":     0,
		"avg_response_time":  0,
		"cache_stats": map[string]interface{}{
			"enabled":         cacheHits > 0 || cacheMisses > 0,
			"cache_hit_ratio": hitRatio,
			"cache_hits":      cacheHits,
			"cache_misses":    cacheMisses,
			"configured_size": 0,
			"entries":         0,
			"capacity":        0,
			"min_ttl":         0,
			"max_ttl":         0,
		},
		"query_types":     []interface{}{},
		"resolver_health": []interface{}{},
		"top_domains":     []interface{}{},
		"sources":         []interface{}{},
		"recent_queries":  []interface{}{},
	}
}

// metricsProxyHandler proxies /api/metrics from monitoring_ui
// (port 8080, section-restricted auth). JSON is passed through
// verbatim; Prometheus text is converted to the Dashboard JSON.
//
// The upstream body is bounded by METRICS_MAX_BODY — an
// unexpectedly large body from monitoring_ui cannot exhaust
// the process heap.
func metricsProxyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "Unauthorized Access"})
		return
	}

	u, p := getMonitoringAuth()
	if u == "" || p == "" {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Monitoring authentication not configured"})
		return
	}

	monitoringURL := "http://127.0.0.1:" + MONITORING_UI_PORT + "/api/metrics"

	req, err := http.NewRequestWithContext(r.Context(), "GET", monitoringURL, nil)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to create proxy request"})
		return
	}
	req.SetBasicAuth(u, p)

	resp, err := dashboardProxyClient.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{"error": "DNSCrypt-Proxy is stopped or unreachable"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{
			"error": fmt.Sprintf("Upstream returned HTTP %d", resp.StatusCode),
		})
		return
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, METRICS_MAX_BODY))
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read upstream response"})
		return
	}

	var upstream map[string]interface{}
	if err := json.Unmarshal(body, &upstream); err == nil {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(upstream)
		return
	}

	prom := parsePrometheus(string(body))
	dashboardJSON := buildDashboardJSON(prom)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(dashboardJSON)
}

// ============================================================
// [36b] Auto-backup + notifications
// ============================================================
// createAutoBackup snapshots the 5 user config files before a
// destructive operation. Rotates after a successful backup to
// bound the total.
//
// The reason string is sanitized before being interpolated into
// the shell command. On failure, the partial target directory
// is removed.
func createAutoBackup(reason string) {
	if _, err := os.Stat(PERSISTENT_BACKUP); err != nil {
		logWithLevel("debug", fmt.Sprintf(
			"auto-backup skipped (%s): %s not initialized", reason, PERSISTENT_BACKUP))
		return
	}

	backupMu.Lock()
	defer backupMu.Unlock()

	funcsScript := getFunctionsScript()
	if _, err := os.Stat(funcsScript); err != nil {
		logWithLevel("debug", "auto-backup skipped: functions.sh not found")
		return
	}

	safeReason := strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') ||
			(r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			return r
		}
		return -1
	}, reason)

	ts := time.Now().Format("20060102-150405")
	randBytes := make([]byte, 2)
	_, _ = rand.Read(randBytes)
	randSuffix := hex.EncodeToString(randBytes)
	targetDir := fmt.Sprintf("%s/%s-manual-%d-%s",
		PERSISTENT_BACKUP, ts, os.Getpid(), randSuffix)

	cmd := fmt.Sprintf(
		". %s; ensure_backup_dir >/dev/null 2>&1; "+
			"backup_user_files %s %s && "+
			". %s; rotate_backups 21 >/dev/null 2>&1",
		shellQuote(funcsScript),
		shellQuote(filepath.Join(MODDIR, "proxy")),
		shellQuote(targetDir),
		shellQuote(funcsScript),
	)

	start := time.Now()
	err := runShellWithTimeout(cmd, AUTO_BACKUP_TIMEOUT)
	elapsed := time.Since(start)

	if err != nil {
		logWithLevel("warn", fmt.Sprintf(
			"⚠️ auto-backup failed (reason=%s, took=%v): %v",
			safeReason, elapsed, err))

		time.Sleep(500 * time.Millisecond)
		if _, statErr := os.Stat(targetDir); statErr == nil {
			if rmErr := os.RemoveAll(targetDir); rmErr != nil {
				logWithLevel("debug", fmt.Sprintf(
					"auto-backup cleanup: could not remove %s: %v",
					filepath.Base(targetDir), rmErr))
			} else {
				logWithLevel("info", fmt.Sprintf(
					"🧹 auto-backup cleanup: removed partial %s",
					filepath.Base(targetDir)))
			}
		}
		return
	}

	logWithLevel("info", fmt.Sprintf(
		"💾 auto-backup complete (reason=%s, took=%v, target=%s)",
		safeReason, elapsed, filepath.Base(targetDir)))
}

// checkPendingNotifications reads and deletes .pending_notification.
// Oversized or invalid-UTF-8 content is discarded.
func checkPendingNotifications() {
	path := PENDING_NOTIFY_FILE

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return
		}
		logWithLevel("warn", "checkPendingNotifications: read failed: "+err.Error())
		_ = os.Remove(path)
		return
	}

	if len(data) == 0 {
		if err := os.Remove(path); err != nil {
			logWithLevel("debug", "checkPendingNotifications: remove failed: "+err.Error())
		}
		return
	}

	const maxNotificationBytes = 4096
	if len(data) > maxNotificationBytes {
		logWithLevel("warn", fmt.Sprintf(
			"checkPendingNotifications: oversized (%d bytes), truncating to %d",
			len(data), maxNotificationBytes))
		data = data[:maxNotificationBytes]
		for len(data) > 0 && !utf8.Valid(data) {
			data = data[:len(data)-1]
		}
	}

	if !utf8.Valid(data) {
		logWithLevel("warn", "checkPendingNotifications: invalid UTF-8, skipping")
		if err := os.Remove(path); err != nil {
			logWithLevel("debug", "checkPendingNotifications: remove failed: "+err.Error())
		}
		return
	}

	msg := strings.TrimSpace(string(data))
	if msg != "" {
		logEvent("📢 " + msg)
	} else {
		logWithLevel("debug", "checkPendingNotifications: empty notification file")
	}

	if err := os.Remove(path); err != nil {
		logWithLevel("debug", "checkPendingNotifications: remove failed: "+err.Error())
	}
}

// ============================================================
// [36c] Transaction cleanup at startup
// ============================================================
// cleanupOldTransactions removes COMMIT'd txn-* directories
// left behind by an interrupted install.
//
// START / ROLLBACK / empty-state directories are PRESERVED —
// they may contain the only copy of a user's data.
func cleanupOldTransactions() {
	if _, err := os.Stat(PERSISTENT_BACKUP); err != nil {
		return
	}

	entries, err := os.ReadDir(PERSISTENT_BACKUP)
	if err != nil {
		logWithLevel("debug", "cleanupOldTransactions: cannot read backup dir: "+err.Error())
		return
	}

	removed := 0
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasPrefix(name, "txn-") {
			continue
		}

		statePath := filepath.Join(PERSISTENT_BACKUP, name, ".state")
		data, err := os.ReadFile(statePath)
		if err != nil {
			continue
		}

		state := strings.TrimSpace(string(data))
		if state == "COMMIT" {
			fullPath := filepath.Join(PERSISTENT_BACKUP, name)
			if err := os.RemoveAll(fullPath); err == nil {
				removed++
			}
		}
	}

	if removed > 0 {
		logEvent(fmt.Sprintf("🧹 cleanupOldTransactions: removed %d COMMIT'd txn dir(s)", removed))
	}
}

// ============================================================
// [37] main
// ============================================================
func main() {
	defer func() {
		if r := recover(); r != nil {
			logWithLevel("error", fmt.Sprintf("FATAL PANIC: %v", r))
			os.Exit(1)
		}
	}()

	initPaths()

	// Load LOG_LEVEL first so every subsequent log call respects
	// the user's configured level (MAIN-01).
	currentLogLevel = loadLogLevel()

	initialProfile := readSelectedProfile()
	applyMemoryLimit(initialProfile)

	watchdogToken := getWatchdogToken()
	if watchdogToken == "" {
		logWithLevel("warn", "⚠️ watchdog token unavailable — ensure_running_service will require user auth")
	} else {
		logWithLevel("debug", "🔑 watchdog token loaded")
	}

	checkPendingNotifications()
	cleanupOldTransactions()

	signal.Ignore(syscall.SIGPIPE)

	serverPort = getWebUIPort()
	dashboardPort := getDashboardPort()

	if serverPort == dashboardPort {
		fmt.Fprintf(os.Stderr, "❌ FATAL: PORT and DASHBOARD_PORT must differ (both = %s)\n", serverPort)
		os.Exit(1)
	}

	if serverPort == MONITORING_UI_PORT {
		fmt.Fprintf(os.Stderr,
			"❌ FATAL: PORT=%s conflicts with [monitoring_ui].\n"+
				"   The port %s is reserved for dnscrypt-proxy's monitoring UI.\n"+
				"   Change PORT in webui.conf (recommended: 9090).\n",
			MONITORING_UI_PORT, MONITORING_UI_PORT)
		os.Exit(1)
	}

	if dashboardPort == MONITORING_UI_PORT {
		fmt.Fprintf(os.Stderr,
			"❌ FATAL: DASHBOARD_PORT=%s conflicts with [monitoring_ui].\n"+
				"   The port %s is reserved for dnscrypt-proxy's monitoring UI.\n"+
				"   Change DASHBOARD_PORT in webui.conf (recommended: 9091).\n",
			MONITORING_UI_PORT, MONITORING_UI_PORT)
		os.Exit(1)
	}

	bindAddr := getBindAddr()
	serverBindAddr = bindAddr

	if isExposedBind(bindAddr) {
		authUser, authPass := getMonitoringAuth()
		if authUser == "" || authPass == "" {
			fmt.Fprintf(os.Stderr, "❌ FATAL: BIND_ADDR=%s but no credentials configured.\n", bindAddr)
			fmt.Fprintf(os.Stderr, "   Refusing to start for security reasons.\n")
			fmt.Fprintf(os.Stderr, "   \n")
			fmt.Fprintf(os.Stderr, "   Fix: either\n")
			fmt.Fprintf(os.Stderr, "     1. Set BIND_ADDR=127.0.0.1 in webui.conf, OR\n")
			fmt.Fprintf(os.Stderr, "     2. Set username/password in dnscrypt-proxy.toml [monitoring_ui]\n")
			os.Exit(1)
		}
	}

	USER_AGENT = buildUserAgent()

	logEvent("🚀 Starting DNSCrypt WebUI " + BuildVersion + " (commit: " + BuildCommit + ")")
	logEvent("🌐 Ports: WebUI=" + serverPort + ", Dashboard=" + dashboardPort)
	logEvent("🔌 Bind:  " + bindAddr)
	logEvent("📂 Runtime dir: " + getActiveRunDir())
	logEvent("📋 LOG_LEVEL=" + currentLogLevel)
	logEvent(fmt.Sprintf("🧠 Profile=%s, memory_limit=%d MB",
		currentProfile, currentMemLimit/(1024*1024)))
	logEvent("📱 Companion APK version: " + readAppVersion())
	logEvent(fmt.Sprintf("🍪 Cookies: Secure=%v, SameSite=Lax", isSecureCookie()))

	if isExposedBind(bindAddr) {
		logWithLevel("warn", "📢 BIND_ADDR="+bindAddr+" — SERVICE IS EXPOSED TO NETWORK")
		logWithLevel("warn", "   Ensure your firewall blocks unauthorized access.")
		logWithLevel("warn", "   Credentials are REQUIRED for all requests.")
	}

	// Seed required runtime files if missing.
	if _, err := os.Stat(SELECTED_FILE); err != nil {
		atomicWriteFile(SELECTED_FILE, []byte("pro"), 0666)
	}
	if _, err := os.Stat(STATUS_FILE); err != nil {
		atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	}

	// Initialize blocklist.raw from blocklist.txt on first run.
	if _, err := os.Stat(RAW_BLOCKLIST_FILE); os.IsNotExist(err) {
		if data, err := os.ReadFile(BLOCKLIST_FILE); err == nil {
			cleaned := stripDenySections(string(data))
			if werr := atomicWriteFile(RAW_BLOCKLIST_FILE, []byte(cleaned), 0644); werr == nil {
				logEvent("✅ blocklist.raw initialized (migrated from blocklist.txt)")
			} else {
				logWithLevel("warn", "⚠️ Failed to init blocklist.raw: "+werr.Error())
			}
		} else {
			atomicWriteFile(RAW_BLOCKLIST_FILE, []byte(""), 0644)
			logEvent("ℹ️ blocklist.raw initialized empty")
		}
	}

	initRulesState()

	startSessionGC()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	httpLogger := log.New(&httpServerLogWriter{}, "", 0)

	mainMux := http.NewServeMux()

	mainMux.HandleFunc("/healthz", handleHealthz)
	mainMux.HandleFunc("/readyz", handleReadyz)

	mainMux.HandleFunc("/api/runtime_info", handleRuntimeInfo)
	mainMux.HandleFunc("/api/runtime_info/", handleRuntimeInfo)
	mainMux.HandleFunc("/api/download_log", handleDownloadLog)
	mainMux.HandleFunc("/api", handleAPI)
	mainMux.HandleFunc("/api/", handleAPI)
	mainMux.HandleFunc("/events", sseHandler)

	serveStaticAssets(mainMux, WEB_FILE, "text/html; charset=utf-8")

	mainServer := &http.Server{
		Addr:              net.JoinHostPort(bindAddr, serverPort),
		Handler:           securityHeadersMiddleware(mainMux),
		ReadTimeout:       HTTP_READ_TIMEOUT,
		ReadHeaderTimeout: 3 * time.Second,
		WriteTimeout:      HTTP_WRITE_TIMEOUT,
		IdleTimeout:       HTTP_IDLE_TIMEOUT,
		ErrorLog:          httpLogger,
	}

	dashboardAddr := net.JoinHostPort(bindAddr, dashboardPort)
	logEvent("📊 Dashboard server listening on " + dashboardAddr)

	dashboardMux := http.NewServeMux()

	dashboardMux.HandleFunc("/healthz", handleHealthz)
	dashboardMux.HandleFunc("/readyz", handleReadyz)

	dashboardMux.HandleFunc("/api/runtime_info", handleRuntimeInfo)
	dashboardMux.HandleFunc("/api/runtime_info/", handleRuntimeInfo)
	dashboardMux.HandleFunc("/api/download_log", handleDownloadLog)
	dashboardMux.HandleFunc("/api", handleAPI)
	dashboardMux.HandleFunc("/api/", handleAPI)
	dashboardMux.HandleFunc("/events", sseHandler)
	dashboardMux.HandleFunc("/api/metrics", metricsProxyHandler)

	serveStaticAssets(dashboardMux, DASHBOARD_FILE, "text/html; charset=utf-8")

	dashboardServer := &http.Server{
		Addr:              dashboardAddr,
		Handler:           securityHeadersMiddleware(dashboardMux),
		ReadTimeout:       HTTP_READ_TIMEOUT,
		ReadHeaderTimeout: 3 * time.Second,
		WriteTimeout:      HTTP_WRITE_TIMEOUT,
		IdleTimeout:       HTTP_IDLE_TIMEOUT,
		ErrorLog:          httpLogger,
	}

	// Shutdown handler: firewall teardown uses the same 90 s
	// budget as startService/stopService. A short 15 s default
	// would leave partial firewall rules in place on a slow
	// device — manage_firewall 0 issues iptables calls that can
	// contend with netd.
	go func() {
		<-sigChan
		logEvent("🛑 Shutdown signal received")
		runShellWithTimeout(
			". "+shellQuote(getFunctionsScript())+"; manage_firewall 0",
			90*time.Second)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		mainServer.Shutdown(ctx)
		dashboardServer.Shutdown(ctx)
		os.Exit(0)
	}()

	go func() {
		if err := dashboardServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logWithLevel("error", "❌ Dashboard server error: "+err.Error())
		}
	}()

	// Main-server ListenAndServe. A bind error (port in use, or
	// permission denied) must terminate the process with a
	// non-zero exit code — otherwise the root manager interprets
	// a successful exit as "started OK" and the module appears
	// functional while the WebUI is unreachable.
	if err := mainServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logWithLevel("error", "❌ Main server error: "+err.Error())
		os.Exit(1)
	}
}

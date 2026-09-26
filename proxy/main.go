// ============================================================
// DNSCrypt Smart Filter – main.go
// Version: v1.1.0
// Author: gasciljh
// Repository: https://github.com/gasciljh/dnscrypt-proxy-webui
// ============================================================
// Purpose:
//   HTTP backend for the DNSCrypt Smart Filter module.
//
//   Responsibilities:
//     • Serve WebUI (port 9090) and Dashboard (port 9091)
//     • Authentication (Basic / Bearer / Cookie session)
//     • Rate limiting (login + Basic Auth)
//     • Blocklist download + rebuild (streaming I/O)
//     • SSE live updates (status, stats, resources, progress)
//     • Metrics proxy (Prometheus → JSON)
//     • Runtime info endpoint (build info + dynamic ports)
//     • Health checks (/healthz + /readyz)
//     • Firewall lifecycle (via shell scripts)
//     • Watchdog integration (via /api/ensure_running_service)
//
// Section structure:
//   [0]  Build version variables
//   [1]  Constants (USER_AGENT)
//   [2]  Global paths
//   [3]  Configuration constants
//   [4]  Types (Profile, Session, LoginAttempt, ...)
//   [5]  Rules state + rebuildMu (RACE-1)
//   [6]  HTTP client (download)
//   [7]  run/ directory management
//   [8]  Global variables
//   [9]  Config readers (readConfValue, readConfPort, BIND_ADDR)
//   [10] Logging (with 1 MB rotation)
//   [11] Atomic writes (atomicWriteFile, atomicWriteStream)
//   [12] Shell command execution (getSystemShell, shellQuote, runShell)
//   [13] HTTP request helper
//   [14] SSE (broadcast, sseHandler, Write Deadline)
//   [15] Statistics (blocked, resources)
//   [16] Local request detection (isLocalRequest, getClientIP)
//   [17] Authentication (getMonitoringAuth, session, checkAuth)
//   [18] Session GC + rate limiting
//   [19] Process/port checks
//   [20] Service lifecycle (startService, stopService, restart)
//   [21] Entries count + validation + progress
//   [22] Download with progress
//   [23] Domain normalization + matching
//   [24] rebuildBlocklist (protected by rebuildMu)
//   [25] Atomic rules save
//   [26] Rules wrappers
//   [27] Profile response
//   [28] updateProfile
//   [29] Old modules detection
//   [30] Log file management
//   [31] runtime_info + /healthz + /readyz
//   [32] API handler (handleAPI)
//   [33] Login handler (handleLogin)
//   [34] Security headers
//   [35] Static asset serving
//   [36] Metrics proxy handler
//   [37] main()
//
// Concurrency model:
//   • rulesStateMu   — sync.RWMutex  — atomic rules state
//   • rebuildMu      — sync.Mutex    — serializes rebuildBlocklist (RACE-1)
//   • sessionsMu     — sync.RWMutex  — session map
//   • loginAttemptsMu— sync.Mutex    — rate limiting (login + Basic Auth)
//   • authCacheMu    — sync.RWMutex  — auth cache (60 s TTL)
//   • serviceMutex   — sync.Mutex    — service lifecycle (TryLock)
//   • portCacheMu    — sync.Mutex    — per-port cache (Fix #11)
//   • systemShellOnce— sync.Once     — platform shell detection (Fix #2)
//   • memLimitMu     — sync.Mutex    — dynamic memory limit (v1.1.0)
//
// Security (v1.0.0):
//   • Login POST-only (Fix NEW-1)
//   • /readyz localhost-only (Fix NEW-4)
//   • Basic Auth rate limiting (Fix #8)
//   • Exact endpoint matching (Fix #12 + NEW-2)
//   • readConfPort range check (Fix NEW-3)
//   • shellQuote injection protection (Fix NEW-5)
//   • Auth cache 60 s (Fix NEW-6)
//   • rebuildMu mutex (RACE-1)
//   • runtime_info ports (PORT-2)
//   • Custom Chains for firewall (no orphans)
//   • STATUS_FILE = user intent
//   • Constant-time password comparison
//
// v1.1.0 additions:
//   • Dynamic memory limit per profile (light/normal/pro/proplus/ultimate)
//   • Extended shellQuote chars ({, }, \n, \t)
//   • MONITORING_UI_PORT constant used everywhere (no more hardcoded "8080")
//
// Build variables (injected via -ldflags at build time):
//   • BuildVersion   — module version (v1.1.0)
//   • BuildCommit    — short git commit hash
//   • BuildTime      — SOURCE_DATE_EPOCH (Unix timestamp)
//   • ProjectURL     — repository URL
// ============================================================

package main

// DNSCrypt Smart Filter — v1.1.0
// Author: gasciljh
// Repository: https://github.com/gasciljh/dnscrypt-proxy-webui

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
	"io"
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
// [1] Constants
// ============================================================
var USER_AGENT = "DNSCrypt-SmartFilter/v1.1.0"

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
	HTTP_WRITE_TIMEOUT     = 0
	HTTP_IDLE_TIMEOUT      = 120 * time.Second
	MAX_LOG_LINES          = 300
	MAX_OLD_MODULES_SHOW   = 50
	MAX_GZ_FILES           = 5
	SERVICE_START_TIMEOUT  = 45 * time.Second
	MIN_BLOCKLIST_SIZE     = 100 * 1024
	SSE_KEEPALIVE_INTERVAL = 15 * time.Second

	SSE_WRITE_TIMEOUT = 30 * time.Second

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

	AUTH_CACHE_TTL = 60 * time.Second

	// v1.1.0 — dynamic memory limits per profile (bytes)
	MEMORY_LIMIT_LIGHT     = 80 * 1024 * 1024   // 80 MB
	MEMORY_LIMIT_NORMAL    = 100 * 1024 * 1024  // 100 MB
	MEMORY_LIMIT_PRO       = 120 * 1024 * 1024  // 120 MB
	MEMORY_LIMIT_PROPLUS   = 160 * 1024 * 1024  // 160 MB
	MEMORY_LIMIT_ULTIMATE  = 220 * 1024 * 1024  // 220 MB
	MEMORY_LIMIT_DEFAULT   = 80 * 1024 * 1024   // 80 MB (fallback)

	DENY_MARKER_START  = "# === CUSTOM_DENYLIST_START ==="
	DENY_MARKER_END    = "# === CUSTOM_DENYLIST_END ==="
	LEGACY_DENY_MARKER = "# === Custom Denylist ==="

	STREAM_WRITE_BUFFER = 64 * 1024
	STREAM_READ_BUFFER  = 64 * 1024
	STREAM_MAX_LINE     = 1024 * 1024

	LOG_MAX_READ_BYTES     = 500 * 1024
	LOG_MAX_DOWNLOAD_BYTES = 100 * 1024 * 1024

	MONITORING_UI_PORT = "8080"
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

// ============================================================
// [5] Rules state — atomic multi-field updates
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
	} else {
		STATUS_FILE = "/data/local/tmp/dnscrypt.status"
		PID_FILE = "/data/local/tmp/dnscrypt.pid"
		PROGRESS_FILE = "/data/local/tmp/update_progress.txt"
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
	updateOnce sync.Once
	logMutex   sync.Mutex

	countCacheMu sync.Mutex
	cachedCount  int
	lastSize     int64
	lastUpdate   string

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

	statsCache  string
	statsTime   time.Time
	statsMutex  sync.Mutex

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

	authCacheMu   sync.RWMutex
	authCacheUser string
	authCachePass string
	authCacheTime time.Time

	// v1.1.0 — dynamic memory limit tracking
	memLimitMu      sync.Mutex
	currentMemLimit int64 = MEMORY_LIMIT_DEFAULT
	currentProfile  string = "pro"
)

type portCacheEntry struct {
	open bool
	time time.Time
}

// ============================================================
// [9] Read webui.conf settings
// ============================================================
func readConfValue(key, defaultValue string) string {
	defer func() { recover() }()
	if data, err := os.ReadFile(CONF_FILE); err == nil {
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
					return val
				}
			}
		}
	}
	return defaultValue
}

func readConfPort(key, defaultPort string) string {
	defer func() { recover() }()
	val := readConfValue(key, defaultPort)
	n, err := strconv.Atoi(val)
	if err != nil || n < 1 || n > 65535 {
		return defaultPort
	}
	return val
}

func getWebUIPort() string     { return readConfPort("PORT", "9090") }
func getDashboardPort() string { return readConfPort("DASHBOARD_PORT", "9091") }

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
// [9d] v1.1.0 — readSelectedProfile + memory limit helpers
// ============================================================
//
// readSelectedProfile returns the active blocklist profile key
// (light/normal/pro/proplus/ultimate), or "pro" as fallback.
//
// This is used to compute the dynamic memory limit at startup
// and after every profile change.
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

// memoryLimitForProfile returns the soft memory limit for a
// given profile key. See MEMORY_LIMIT_* constants.
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
// on the active profile. The old limit is returned via the
// runtime, and we log the transition.
//
// Note: debug.SetMemoryLimit is a SOFT limit — the runtime will
// prefer to run GC more aggressively rather than OOM. Setting
// it too low causes GC overhead; setting it too high wastes RAM.
// Hence the per-profile values.
func applyMemoryLimit(key string) {
	memLimitMu.Lock()
	defer memLimitMu.Unlock()

	limit := memoryLimitForProfile(key)
	if limit == currentMemLimit && key == currentProfile {
		return
	}

	old := debug.SetMemoryLimit(limit)
	currentMemLimit = limit
	currentProfile = key

	logWithLevel("info", fmt.Sprintf(
		"memory limit adjusted: %d MB → %d MB (profile=%s, previous runtime value=%d MB)",
		old/(1024*1024), limit/(1024*1024), key, old/(1024*1024)))
}

// ============================================================
// [10] Logging
// ============================================================
func logWithLevel(level, msg string) {
	levelMap := map[string]int{"error": 0, "warn": 1, "info": 2, "debug": 3}
	current := levelMap[currentLogLevel]
	required := levelMap[level]

	if required > current {
		return
	}

	logMutex.Lock()
	defer logMutex.Unlock()
	defer func() { recover() }()

	if len(msg) > MAX_LOG_MSG_SIZE {
		msg = msg[:MAX_LOG_MSG_SIZE] + "...[truncated]"
	}

	if fi, err := os.Stat(LOG_FILE); err == nil && fi.Size() > MAX_LOG_SIZE {
		timestampFile := fmt.Sprintf("%s.%d.old", LOG_FILE, time.Now().UnixNano())
		if err := os.Rename(LOG_FILE, timestampFile); err == nil {
			go compressLogFile(timestampFile)
		}
	}

	f, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
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

func compressLogFile(filePath string) {
	defer func() { recover() }()
	src, err := os.Open(filePath)
	if err != nil {
		return
	}
	defer src.Close()
	dest, err := os.Create(filePath + ".gz")
	if err != nil {
		return
	}
	defer dest.Close()
	gzWriter := gzip.NewWriter(dest)
	defer gzWriter.Close()
	io.Copy(gzWriter, src)
	os.Remove(filePath)
	cleanupOldGz(filepath.Dir(filePath))
}

func cleanupOldGz(dir string) {
	defer func() { recover() }()
	files, err := filepath.Glob(filepath.Join(dir, "*.gz"))
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

	success = true
	return nil
}

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

	_ = f.Chmod(perm)

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

	if err := f.Close(); err != nil {
		return fmt.Errorf("close: %w", err)
	}

	if err := os.Rename(tmpName, filename); err != nil {
		return fmt.Errorf("rename tmp: %w", err)
	}

	success = true
	return nil
}

// ============================================================
// [12] Shell command execution
// ============================================================
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

// shellQuote wraps s in single quotes if it contains any shell
// metacharacter, escaping embedded single quotes via the
// standard '\'' sequence.
//
// v1.1.0: extended to cover {, }, \n, \t in addition to the
// original set. This protects against brace expansion and
// whitespace-based word splitting.
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

func runShell(cmd string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	command := exec.CommandContext(ctx, getSystemShell(), "-c", cmd)
	command.Stdout = io.Discard

	errBuf := &limitedBuffer{max: MAX_STDERR_CAPTURE}
	command.Stderr = errBuf

	err := command.Run()
	if err != nil {
		errOutput := strings.TrimSpace(errBuf.String())
		if errOutput != "" {
			logWithLevel("warn", fmt.Sprintf("⚠️ Shell failed: %s (%v) stderr: %s",
				cmd, err, errOutput))
		} else {
			logWithLevel("warn", fmt.Sprintf("⚠️ Shell failed: %s (%v)", cmd, err))
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
	req.Header.Set("User-Agent", USER_AGENT)
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
	sseMutex.Lock()
	sseClients[ch] = true
	sseMutex.Unlock()

	ch <- fmt.Sprintf("event: status\ndata: %s\n\n", getStatus())
	ch <- fmt.Sprintf("event: stats\ndata: {\"blocked_today\":\"%s\"}\n\n", getBlockedStats())
	ch <- fmt.Sprintf("event: resources\ndata: {\"ram\":\"%s\"}\n\n", getResourceUsage())

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
func getBlockedStats() string {
	statsMutex.Lock()
	defer statsMutex.Unlock()
	if time.Since(statsTime) < 300*time.Second && statsCache != "" {
		return statsCache
	}
	logFile := "/data/local/tmp/dnscrypt-blocked.log"
	cmd := exec.Command("grep", "-c", time.Now().Format("2006-01-02"), logFile)
	out, err := cmd.Output()
	if err != nil {
		statsCache = "0"
	} else {
		count := strings.TrimSpace(string(out))
		if count == "" {
			count = "0"
		}
		statsCache = count
	}
	statsTime = time.Now()
	return statsCache
}

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
func isLocalRequest(r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	host = strings.Trim(host, "[]")
	return host == "127.0.0.1" || host == "::1" || host == "localhost"
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
func getMonitoringAuth() (username, password string) {
	authCacheMu.RLock()
	if !authCacheTime.IsZero() && time.Since(authCacheTime) < AUTH_CACHE_TTL {
		u, p := authCacheUser, authCachePass
		authCacheMu.RUnlock()
		return u, p
	}
	authCacheMu.RUnlock()

	user, pass := readMonitoringAuthFromFile()

	authCacheMu.Lock()
	authCacheUser = user
	authCachePass = pass
	authCacheTime = time.Now()
	authCacheMu.Unlock()

	return user, pass
}

func readMonitoringAuthFromFile() (username, password string) {
	defer func() { recover() }()

	data, err := os.ReadFile(CONF)
	if err != nil {
		return "", ""
	}

	inSection := false
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if trimmed == "" {
			continue
		}

		if strings.HasPrefix(trimmed, "#") {
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
		val := strings.TrimSpace(trimmed[eqIdx+1:])

		if idx := strings.Index(val, " #"); idx > 0 {
			val = strings.TrimSpace(val[:idx])
		}

		val = strings.Trim(val, `"'`)

		switch key {
		case "username":
			username = val
		case "password":
			password = val
		}
	}

	return username, password
}

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

// ============================================================
// [18] Session & LoginAttempts GC
// ============================================================
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

			if sessRemoved > 0 || attemptsRemoved > 0 {
				logWithLevel("debug", fmt.Sprintf(
					"🧹 GC removed: %d session(s), %d login attempt(s)",
					sessRemoved, attemptsRemoved))
			}
		}
	}()
}

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

func checkAuth(r *http.Request) bool {
	if isLocalRequest(r) {
		if r.Method == http.MethodPost &&
			hasEndpoint(r.URL.Path, "ensure_running_service") {
			return true
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
// [19] Process and port checks
// ============================================================
func isPidAlive(pid int) bool {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
	if err != nil {
		return false
	}
	return strings.Contains(string(data), "dnscrypt")
}

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

	cmd := fmt.Sprintf(". %s/functions.sh; is_port_open %d udp", shellQuote(MODDIR), port)
	return runShell(cmd) == nil
}

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

func getStatusUncached() string {
	defer func() { recover() }()

	_, found := isProcessRunning()
	if !found || !isPortOpenCached(5354) {
		return "OFF"
	}
	return "ON"
}

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
func startService() {
	defer func() { recover() }()
	logEvent("▶️ Starting service...")
	invalidateStatusCache()
	if getStatus() == "ON" {
		return
	}
	if !ensureExecutable(BIN) {
		return
	}
	runShell(". " + shellQuote(MODDIR) + "/functions.sh; cleanup_proxy")
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
		runShell(". " + shellQuote(MODDIR) + "/functions.sh; cleanup_proxy")
		os.Remove(PID_FILE)
		atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
		invalidateStatusCache()
		return
	}
	runShell("settings delete global private_dns_mode")
	runShell(". " + shellQuote(MODDIR) + "/functions.sh; manage_firewall 1")
	atomicWriteFile(STATUS_FILE, []byte("ON"), 0666)
	invalidateStatusCache()
	logEvent("✅ Service started (PID: " + strconv.Itoa(pid) + ")")
	runShell("ndc resolver flushdefaultif 2>/dev/null || true")
	broadcastEvent("status", "ON")
	broadcastEvent("resources", fmt.Sprintf("{\"ram\":\"%s\"}", getResourceUsage()))
}

func stopService() {
	defer func() { recover() }()
	logEvent("⏹️ Stopping service...")
	portCacheMu.Lock()
	portCacheMap = make(map[int]portCacheEntry)
	portCacheMu.Unlock()
	atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	invalidateStatusCache()

	runShell("pkill -9 dnscrypt-proxy")
	runShell(". " + shellQuote(MODDIR) + "/functions.sh; cleanup_proxy")
	os.Remove(PID_FILE)
	runShell(". " + shellQuote(MODDIR) + "/functions.sh; manage_firewall 0")
	atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	invalidateStatusCache()
	logEvent("✅ Service stopped")
	broadcastEvent("status", "OFF")
	broadcastEvent("resources", "{\"ram\":\"N/A\"}")
}

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
func getEntriesCount() int {
	defer func() { recover() }()

	countCacheMu.Lock()
	defer countCacheMu.Unlock()

	fi, err := os.Stat(BLOCKLIST_FILE)
	if err != nil || fi.Size() == 0 {
		return 0
	}
	if fi.Size() == lastSize && cachedCount > 0 {
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
	return count
}

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

func writeProgress(percent int, msg string) {
	atomicWriteFile(PROGRESS_FILE, []byte(fmt.Sprintf("%d|%s", percent, msg)), 0666)
	broadcastEvent("progress", fmt.Sprintf("%d|%s", percent, msg))
}

// ============================================================
// [22] Download
// ============================================================
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

func stripDenySections(content string) string {
	if idx := strings.Index(content, DENY_MARKER_START); idx >= 0 {
		content = content[:idx]
	}
	if idx := strings.Index(content, LEGACY_DENY_MARKER); idx >= 0 {
		content = content[:idx]
	}
	return strings.TrimRight(content, " \t\r\n") + "\n"
}

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
	return runAtomicSave(saveRulesRequest{
		AllowContent:      content,
		ExpectedAllowHash: expectedHash,
		UpdateAllow:       true,
	}, "allow")
}

func saveDenylist(content, expectedHash string) map[string]interface{} {
	return runAtomicSave(saveRulesRequest{
		DenyContent:      content,
		ExpectedDenyHash: expectedHash,
		UpdateDeny:       true,
	}, "deny")
}

func saveCustomRulesCombined(allow, deny string) map[string]interface{} {
	return runAtomicSave(saveRulesRequest{
		AllowContent: allow,
		DenyContent:  deny,
		UpdateAllow:  true,
		UpdateDeny:   true,
	}, "allow")
}

func appendDenylist() map[string]interface{} {
	denyData, err := os.ReadFile(DENYLIST_FILE)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot read denylist.txt",
		}
	}
	currentHash := fileHash(DENYLIST_FILE)
	result := saveDenylist(string(denyData), currentHash)

	if result["status"] == "ok" {
		entries, _ := result["entries"].(int)
		result["message"] = fmt.Sprintf("Processed %d rules", entries)
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

	updateOnce.Do(func() {
		if fi, err := os.Stat(BLOCKLIST_FILE); err == nil {
			countCacheMu.Lock()
			lastUpdate = fi.ModTime().Format("2006-01-02 15:04:05")
			countCacheMu.Unlock()
		}
	})

	countCacheMu.Lock()
	lastUpdateCopy := lastUpdate
	countCacheMu.Unlock()

	return map[string]interface{}{
		"key":         key,
		"name":        name,
		"entries":     entries,
		"is_empty":    entries == 0,
		"last_update": lastUpdateCopy,
		"memory_limit_mb": memoryLimitForProfile(key) / (1024 * 1024),
	}
}

// ============================================================
// [28] Update profile
// ============================================================
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

	writeProgress(5, "Connecting to blocklist servers...")
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
		if data, rerr := os.ReadFile(tempFile); rerr == nil {
			if werr := atomicWriteFile(RAW_BLOCKLIST_FILE, data, 0644); werr != nil {
				writeProgress(0, "❌ Failed to save base file")
				return map[string]interface{}{"status": "error", "message": "Failed to save base file"}
			}
		} else {
			writeProgress(0, "❌ Failed to move file")
			return map[string]interface{}{"status": "error", "message": "Failed to move file"}
		}
	}

	writeProgress(90, "Applying custom rules...")
	time.Sleep(500 * time.Millisecond)

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

	// v1.1.0 — adjust memory limit based on the new profile
	applyMemoryLimit(key)

	writeProgress(95, "Restarting DNSCrypt engine...")
	time.Sleep(500 * time.Millisecond)

	if wasRunning {
		startService()
	}
	time.Sleep(1500 * time.Millisecond)

	entries := getEntriesCount()

	countCacheMu.Lock()
	lastUpdate = time.Now().Format("2006-01-02 15:04:05")
	lastUpdateCopy := lastUpdate
	countCacheMu.Unlock()

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

func removeModule(modulePath string) map[string]interface{} {
	defer func() { recover() }()
	cleanPath := filepath.Clean(modulePath)
	if !strings.HasPrefix(cleanPath+string(filepath.Separator), MODULES_DIR+string(filepath.Separator)) {
		return map[string]interface{}{"status": "error", "message": "Invalid path"}
	}
	if cleanPath == MODDIR {
		return map[string]interface{}{"status": "error", "message": "Cannot remove current module"}
	}
	fingerprintData, err := os.ReadFile(filepath.Join(cleanPath, ".module.fingerprint"))
	if err != nil {
		return map[string]interface{}{"status": "error", "message": "Module has no valid fingerprint"}
	}
	if !strings.Contains(string(fingerprintData), "dnscrypt-proxy-webui") {
		return map[string]interface{}{"status": "error", "message": "This is not a DNSCrypt Proxy module"}
	}
	if err := os.RemoveAll(cleanPath); err != nil {
		logWithLevel("error", "❌ removeModule failed: "+err.Error())
		return map[string]interface{}{"status": "error", "message": "Failed to remove module"}
	}
	oldModulesMutex.Lock()
	oldModulesCache = nil
	oldModulesTime = time.Time{}
	oldModulesMutex.Unlock()
	return map[string]interface{}{"status": "ok", "message": "Old module removed successfully"}
}

// ============================================================
// [30] Log file management
// ============================================================
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
		name := entry.Name()
		if !isAllowedLogFile(name) {
			continue
		}
		info, err := entry.Info()
		if err != nil {
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

func readLogFile(name, confirm string) map[string]interface{} {
	if !isAllowedLogFile(name) {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not allowed",
		}
	}

	if isSensitiveFile(name) && confirm != "1" {
		return map[string]interface{}{
			"status":  "requires_confirm",
			"message": "Sensitive file requires confirmation",
			"name":    name,
		}
	}

	path := filepath.Join(LOGS_DIR, name)
	info, err := os.Stat(path)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found",
		}
	}

	var content string
	var truncated bool

	if strings.HasSuffix(name, ".gz") {
		f, err := os.Open(path)
		if err != nil {
			return map[string]interface{}{
				"status":  "error",
				"message": "Cannot open file",
			}
		}
		defer f.Close()

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
		f, err := os.Open(path)
		if err != nil {
			return map[string]interface{}{
				"status":  "error",
				"message": "Cannot open file",
			}
		}
		defer f.Close()

		readSize := info.Size()
		if readSize > LOG_MAX_READ_BYTES {
			f.Seek(-LOG_MAX_READ_BYTES, io.SeekEnd)
			readSize = LOG_MAX_READ_BYTES
			truncated = true
		}

		data := make([]byte, readSize)
		n, _ := io.ReadFull(f, data)
		content = string(data[:n])
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

func clearLogFile(name string) map[string]interface{} {
	if !isAllowedLogFile(name) {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not allowed",
		}
	}

	if isSensitiveFile(name) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot clear sensitive file",
		}
	}

	if name == filepath.Base(LOG_FILE) {
		return map[string]interface{}{
			"status":  "error",
			"message": "Cannot clear the active system log",
		}
	}

	path := filepath.Join(LOGS_DIR, name)
	info, err := os.Stat(path)
	if err != nil {
		return map[string]interface{}{
			"status":  "error",
			"message": "File not found",
		}
	}

	if !info.Mode().IsRegular() {
		return map[string]interface{}{
			"status":  "error",
			"message": "File is not a regular file",
		}
	}

	if err := os.Truncate(path, 0); err != nil {
		logWithLevel("error", "❌ clearLogFile failed for "+name+": "+err.Error())
		return map[string]interface{}{
			"status":  "error",
			"message": "Failed to clear file",
		}
	}

	logEvent("🗑️ Cleared log file: " + name)
	return map[string]interface{}{
		"status":  "ok",
		"message": "File cleared successfully",
	}
}

func handleDownloadLog(w http.ResponseWriter, r *http.Request) {
	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		fmt.Fprint(w, "Unauthorized")
		return
	}

	name := r.URL.Query().Get("file")
	if !isAllowedLogFile(name) {
		w.WriteHeader(http.StatusForbidden)
		fmt.Fprint(w, "Forbidden")
		return
	}

	if isSensitiveFile(name) && r.URL.Query().Get("confirm") != "1" {
		w.WriteHeader(http.StatusForbidden)
		fmt.Fprint(w, "Confirmation required")
		return
	}

	path := filepath.Join(LOGS_DIR, name)
	info, err := os.Stat(path)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	if info.Size() > LOG_MAX_DOWNLOAD_BYTES {
		w.WriteHeader(http.StatusRequestEntityTooLarge)
		fmt.Fprint(w, "File too large")
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, name))
	w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	f, err := os.Open(path)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Cannot open file")
		return
	}
	defer f.Close()

	io.Copy(w, f)
}

// ============================================================
// [31] runtime_info
// ============================================================
func buildRuntimeInfo() map[string]interface{} {
	info := map[string]interface{}{
		"version":       BuildVersion,
		"commit":        BuildCommit,
		"build_time":    BuildTime,
		"project_url":   ProjectURL,
		"run_dir":       getActiveRunDir(),
		"status_file":   STATUS_FILE,
		"pid_file":      PID_FILE,
		"progress_file": PROGRESS_FILE,
		"log_file":      LOG_FILE,
		"bind_addr":     getBindAddr(),

		"webui_port":     getWebUIPort(),
		"dashboard_port": getDashboardPort(),

		// v1.1.0 — expose dynamic memory limit state
		"memory_limit_mb": memoryLimitForProfile(currentProfile) / (1024 * 1024),
		"profile_key":     currentProfile,
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
func hasEndpoint(path, name string) bool {
	if path == "/api/"+name {
		return true
	}
	if path == "/api/"+name+"/" {
		return true
	}
	return false
}

func handleAPI(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if rec := recover(); rec != nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Internal server error"})
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")

	if r.Method == http.MethodOptions {
		w.Header().Set("Allow", "GET, POST, OPTIONS")
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if hasEndpoint(r.URL.Path, "auth/login") {
		if r.Method != http.MethodPost {
			w.Header().Set("Allow", "POST")
			w.WriteHeader(http.StatusMethodNotAllowed)
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "error",
				"message": "Login requires POST (CSRF protection)",
			})
			return
		}
		handleLogin(w, r)
		return
	}

	if hasEndpoint(r.URL.Path, "auth/logout") {
		if r.Method != http.MethodPost {
			w.Header().Set("Allow", "POST")
			w.WriteHeader(http.StatusMethodNotAllowed)
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "error",
				"message": "Logout requires POST (CSRF protection)",
			})
			return
		}

		if cookie, err := r.Cookie(SESSION_COOKIE_NAME); err == nil {
			destroySession(cookie.Value)
		}
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			destroySession(strings.TrimPrefix(authHeader, "Bearer "))
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
		return
	}

	if !checkAuth(r) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Unauthorized"})
		return
	}

	if r.Method == http.MethodPost {
		r.Body = http.MaxBytesReader(w, r.Body, MAX_POST_BODY_SIZE)
	}

	if r.Method == http.MethodPost {
		if hasEndpoint(r.URL.Path, "update_profile") {
			profile := r.FormValue("profile")
			if profile == "" {
				profile = "pro"
			}
			go updateProfile(profile)
			json.NewEncoder(w).Encode(map[string]string{"status": "processing", "message": "Update in progress..."})
			return
		}

		if hasEndpoint(r.URL.Path, "save_allowlist") {
			content := r.FormValue("allowlist")
			expectedHash := r.FormValue("expected_hash")
			result := saveAllowlist(content, expectedHash)
			if result["status"] == "conflict" {
				w.WriteHeader(http.StatusConflict)
			}
			json.NewEncoder(w).Encode(result)
			return
		}

		if hasEndpoint(r.URL.Path, "save_denylist") {
			content := r.FormValue("denylist")
			expectedHash := r.FormValue("expected_hash")
			result := saveDenylist(content, expectedHash)
			if result["status"] == "conflict" {
				w.WriteHeader(http.StatusConflict)
			}
			json.NewEncoder(w).Encode(result)
			return
		}

		if hasEndpoint(r.URL.Path, "save_custom_rules") {
			allow := r.FormValue("allowlist")
			deny := r.FormValue("denylist")
			result := saveCustomRulesCombined(allow, deny)
			json.NewEncoder(w).Encode(result)
			return
		}

		if hasEndpoint(r.URL.Path, "append_denylist") {
			result := appendDenylist()
			json.NewEncoder(w).Encode(result)
			return
		}

		if hasEndpoint(r.URL.Path, "remove_module") {
			json.NewEncoder(w).Encode(removeModule(r.FormValue("path")))
			return
		}

		if hasEndpoint(r.URL.Path, "clear_log_file") {
			name := r.FormValue("file")
			result := clearLogFile(name)
			json.NewEncoder(w).Encode(result)
			return
		}

		if hasEndpoint(r.URL.Path, "clear_logs") {
			os.Truncate(LOG_FILE, 0)
			json.NewEncoder(w).Encode(map[string]string{"status": "ok", "message": "Logs cleared successfully"})
			return
		}

		if hasEndpoint(r.URL.Path, "toggle_service") {
			if !serviceMutex.TryLock() {
				json.NewEncoder(w).Encode(map[string]interface{}{
					"status": "error", "message": "Service is busy"})
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
			return
		}

		if hasEndpoint(r.URL.Path, "restart_service") {
			if !serviceMutex.TryLock() {
				json.NewEncoder(w).Encode(map[string]interface{}{
					"status": "error", "message": "Service is busy"})
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
			return
		}

		if hasEndpoint(r.URL.Path, "ensure_running_service") {
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
			return
		}

		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"status": "error", "message": "Unsupported POST endpoint"})
		return
	}

	action := r.URL.Query().Get("action")
	var res map[string]interface{}
	httpStatus := http.StatusOK

	switch action {
	case "status":
		res = map[string]interface{}{"status": getStatus()}

	case "get_profile":
		res = buildProfileResponse()

	case "get_custom_rules":
		allow, _ := os.ReadFile(ALLOWLIST_FILE)
		deny, _ := os.ReadFile(DENYLIST_FILE)
		res = map[string]interface{}{"allowlist": string(allow), "denylist": string(deny)}

	case "get_rules_state":
		s := getRulesState()
		res = map[string]interface{}{
			"allowlist_hash": s.AllowlistHash,
			"denylist_hash":  s.DenylistHash,
		}

	case "stats":
		res = map[string]interface{}{"blocked_today": getBlockedStats()}

	case "resources":
		res = map[string]interface{}{"ram": getResourceUsage()}

	case "runtime_info":
		res = buildRuntimeInfo()

	case "logs":
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
		res = map[string]interface{}{"logs": content}

	case "list_logs":
		res = listLogFiles()

	case "read_log":
		name := r.URL.Query().Get("file")
		confirm := r.URL.Query().Get("confirm")
		res = readLogFile(name, confirm)

	case "get_progress":
		d, _ := os.ReadFile(PROGRESS_FILE)
		progress := "0|"
		if len(d) > 0 {
			progress = strings.TrimSpace(string(d))
		}
		res = map[string]interface{}{"progress": progress}

	case "check_old_modules":
		old := checkOldModules()
		res = map[string]interface{}{"modules": old, "count": len(old)}

	case "toggle", "restart", "ensure_running":
		w.Header().Set("Allow", "POST")
		w.WriteHeader(http.StatusMethodNotAllowed)
		res = map[string]interface{}{
			"status":  "error",
			"message": "This endpoint requires POST (CSRF-GET protection)",
			"hint":    fmt.Sprintf("Use POST /api/%s_service", action),
		}

	case "":
		httpStatus = http.StatusNotFound
		res = map[string]interface{}{
			"status":  "error",
			"message": "missing 'action' parameter",
			"hint":    "Use GET /api?action=<name>",
		}

	default:
		httpStatus = http.StatusNotFound
		res = map[string]interface{}{
			"status":  "error",
			"message": fmt.Sprintf("unknown action: %q", action),
		}
	}

	if httpStatus != http.StatusOK {
		w.WriteHeader(httpStatus)
	}
	json.NewEncoder(w).Encode(res)
}

// ============================================================
// [33] Login handler
// ============================================================
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

	logEvent("🔐 User '" + username + "' logged in from " + ip)

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

func serveFile(w http.ResponseWriter, r *http.Request, path, contentType string) {
	setSecurityHeaders(w)
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
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

func findMetric(prom map[string]float64, names ...string) float64 {
	for _, name := range names {
		if v, ok := prom[name]; ok {
			return v
		}
	}
	return 0
}

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

	// v1.1.0 — use the MONITORING_UI_PORT constant instead of
	// a hardcoded "8080". This keeps the reserved-port definition
	// in a single place.
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

	body, err := io.ReadAll(resp.Body)
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

	// v1.1.0 — dynamic memory limit based on the active profile
	// (replaces the previous hardcoded debug.SetMemoryLimit(80MB))
	initialProfile := readSelectedProfile()
	applyMemoryLimit(initialProfile)

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

	currentLogLevel = loadLogLevel()

	USER_AGENT = fmt.Sprintf("DNSCrypt-SmartFilter/%s (Android; +%s)",
		strings.TrimPrefix(BuildVersion, "v"), ProjectURL)

	logEvent("🚀 Starting DNSCrypt WebUI " + BuildVersion + " (commit: " + BuildCommit + ")")
	logEvent("📋 LOG_LEVEL=" + currentLogLevel)
	logEvent("🌐 Ports: WebUI=" + serverPort + ", Dashboard=" + dashboardPort)
	logEvent("🔌 Bind:  " + bindAddr)
	logEvent("📂 Runtime dir: " + getActiveRunDir())
	logEvent("🏷️  User-Agent: " + USER_AGENT)
	logEvent("🔗 Project URL: " + ProjectURL)
	logEvent(fmt.Sprintf("🍪 Cookies: Secure=%v, SameSite=Lax", isSecureCookie()))
	logEvent(fmt.Sprintf("📡 SSE: WriteTimeout=%v, Keepalive=%v", SSE_WRITE_TIMEOUT, SSE_KEEPALIVE_INTERVAL))
	logEvent(fmt.Sprintf("🧹 GC: Sessions=%v, LoginAttempts=%v", SESSION_GC_PERIOD, LOGIN_ATTEMPT_STALE_PERIOD))
	logEvent(fmt.Sprintf("🔒 Audit: stderr_capture=%d bytes (bounded)", MAX_STDERR_CAPTURE))
	logEvent("🛡️  CSRF: toggle/restart/ensure_running → POST only")
	logEvent("🔒 Auth: cookie-only + Basic Auth rate-limited")
	logEvent("🔥 Custom chains: STATUS_FILE=user-intent, getClientIP=IPv6-safe, PORT!=8080")
	logEvent("🆕 v1.0.0: shell=fallback, section-header=comment-aware")
	logEvent("🆕 v1.0.0: hasEndpoint=exact-match (in handleAPI + checkAuth)")
	logEvent("🆕 v1.0.0: panic → os.Exit(1)")
	logEvent("🆕 v1.0.0: login POST-only + /readyz local-only + readConfPort range + auth cache")
	logEvent("🆕 v1.0.0: rebuildMu (RACE-1) + runtime_info ports (PORT-2)")
	logEvent("✅ v1.0.0: metricsProxyHandler → /api/metrics (JSON pass-through)")
	logEvent("🎨 Asset Serving: 11 static files (SVG + PNG + ICO + offline.html)")
	logEvent(fmt.Sprintf("🧠 v1.1.0: dynamic memory limit — profile=%s, limit=%d MB",
		currentProfile, currentMemLimit/(1024*1024)))
	logEvent("🧠 v1.1.0: shellQuote extended ({, }, \\n, \\t)")
	logEvent("🧠 v1.1.0: MONITORING_UI_PORT constant used in metricsProxyHandler")

	if isExposedBind(bindAddr) {
		logWithLevel("warn", "🔓 BIND_ADDR="+bindAddr+" — SERVICE IS EXPOSED TO NETWORK")
		logWithLevel("warn", "   Ensure your firewall blocks unauthorized access.")
		logWithLevel("warn", "   Credentials are REQUIRED for all requests.")
	}

	if _, err := os.Stat(SELECTED_FILE); err != nil {
		atomicWriteFile(SELECTED_FILE, []byte("pro"), 0666)
	}
	if _, err := os.Stat(STATUS_FILE); err != nil {
		atomicWriteFile(STATUS_FILE, []byte("OFF"), 0666)
	}

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
	{
		s := getRulesState()
		aHash := s.AllowlistHash
		dHash := s.DenylistHash
		if len(aHash) > 12 {
			aHash = aHash[:12]
		}
		if len(dHash) > 12 {
			dHash = dHash[:12]
		}
		if aHash == "" {
			aHash = "(none)"
		}
		if dHash == "" {
			dHash = "(none)"
		}
		logEvent(fmt.Sprintf("📋 Rules state: allow=%s deny=%s", aHash, dHash))
	}

	startSessionGC()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	mainMux := http.NewServeMux()

	mainMux.HandleFunc("/healthz", handleHealthz)
	mainMux.HandleFunc("/readyz", handleReadyz)

	mainMux.HandleFunc("/api/runtime_info", handleRuntimeInfo)
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
	}

	dashboardAddr := net.JoinHostPort(bindAddr, dashboardPort)
	logEvent("📊 Dashboard server listening on " + dashboardAddr)

	dashboardMux := http.NewServeMux()

	dashboardMux.HandleFunc("/healthz", handleHealthz)
	dashboardMux.HandleFunc("/readyz", handleReadyz)

	dashboardMux.HandleFunc("/api/runtime_info", handleRuntimeInfo)
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
	}

	go func() {
		<-sigChan
		logEvent("🛑 Shutdown signal received")
		runShell(". " + shellQuote(MODDIR) + "/functions.sh; manage_firewall 0")
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

	if err := mainServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logWithLevel("error", "❌ Main server error: "+err.Error())
	}
}
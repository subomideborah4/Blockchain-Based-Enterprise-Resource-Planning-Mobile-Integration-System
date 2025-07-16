;; Mobile App Contract
;; Manages ERP mobile applications

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-APP-NOT-FOUND (err u201))
(define-constant ERR-INVALID-VERSION (err u202))
(define-constant ERR-ALREADY-EXISTS (err u203))
(define-constant ERR-INVALID-INPUT (err u204))

;; Data Variables
(define-data-var next-app-id uint u1)

;; Data Maps
(define-map mobile-apps
  { app-id: uint }
  {
    name: (string-ascii 50),
    developer: principal,
    version: (string-ascii 20),
    platform: (string-ascii 20),
    status: (string-ascii 20),
    deployment-date: uint,
    is-active: bool,
    compatibility-score: uint
  }
)

(define-map app-usage-stats
  { app-id: uint }
  {
    total-downloads: uint,
    active-users: uint,
    crash-rate: uint,
    performance-score: uint,
    last-updated: uint
  }
)

(define-map app-versions
  { app-id: uint, version: (string-ascii 20) }
  {
    release-date: uint,
    changelog: (string-ascii 200),
    is-stable: bool,
    download-count: uint
  }
)

(define-map developer-apps
  { developer: principal }
  { app-ids: (list 50 uint) }
)

;; Public Functions

;; Register a new mobile app
(define-public (register-app (name (string-ascii 50)) (version (string-ascii 20)) (platform (string-ascii 20)))
  (let
    (
      (app-id (var-get next-app-id))
      (developer tx-sender)
    )
    (asserts! (< (len name) u51) ERR-INVALID-INPUT)
    (asserts! (< (len version) u21) ERR-INVALID-INPUT)
    (asserts! (< (len platform) u21) ERR-INVALID-INPUT)

    (map-set mobile-apps
      { app-id: app-id }
      {
        name: name,
        developer: developer,
        version: version,
        platform: platform,
        status: "development",
        deployment-date: block-height,
        is-active: true,
        compatibility-score: u0
      }
    )

    (map-set app-versions
      { app-id: app-id, version: version }
      {
        release-date: block-height,
        changelog: "Initial release",
        is-stable: false,
        download-count: u0
      }
    )

    ;; Update developer apps list
    (let
      (
        (current-apps (default-to (list) (get app-ids (map-get? developer-apps { developer: developer }))))
      )
      (map-set developer-apps
        { developer: developer }
        { app-ids: (unwrap! (as-max-len? (append current-apps app-id) u50) ERR-INVALID-INPUT) }
      )
    )

    (var-set next-app-id (+ app-id u1))
    (ok app-id)
  )
)

;; Update app status
(define-public (update-app-status (app-id uint) (status (string-ascii 20)))
  (let
    (
      (app (unwrap! (map-get? mobile-apps { app-id: app-id }) ERR-APP-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get developer app))) ERR-NOT-AUTHORIZED)
    (asserts! (< (len status) u21) ERR-INVALID-INPUT)

    (map-set mobile-apps
      { app-id: app-id }
      (merge app { status: status })
    )
    (ok true)
  )
)

;; Release new version
(define-public (release-version (app-id uint) (version (string-ascii 20)) (changelog (string-ascii 200)))
  (let
    (
      (app (unwrap! (map-get? mobile-apps { app-id: app-id }) ERR-APP-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get developer app)) ERR-NOT-AUTHORIZED)
    (asserts! (< (len version) u21) ERR-INVALID-INPUT)
    (asserts! (< (len changelog) u201) ERR-INVALID-INPUT)

    ;; Update main app record
    (map-set mobile-apps
      { app-id: app-id }
      (merge app { version: version })
    )

    ;; Add version record
    (map-set app-versions
      { app-id: app-id, version: version }
      {
        release-date: block-height,
        changelog: changelog,
        is-stable: false,
        download-count: u0
      }
    )
    (ok true)
  )
)

;; Update usage statistics
(define-public (update-usage-stats (app-id uint) (downloads uint) (active-users uint) (crash-rate uint) (performance-score uint))
  (let
    (
      (app (unwrap! (map-get? mobile-apps { app-id: app-id }) ERR-APP-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get developer app))) ERR-NOT-AUTHORIZED)
    (asserts! (<= crash-rate u100) ERR-INVALID-INPUT)
    (asserts! (<= performance-score u100) ERR-INVALID-INPUT)

    (map-set app-usage-stats
      { app-id: app-id }
      {
        total-downloads: downloads,
        active-users: active-users,
        crash-rate: crash-rate,
        performance-score: performance-score,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

;; Update compatibility score
(define-public (update-compatibility-score (app-id uint) (score uint))
  (let
    (
      (app (unwrap! (map-get? mobile-apps { app-id: app-id }) ERR-APP-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= score u100) ERR-INVALID-INPUT)

    (map-set mobile-apps
      { app-id: app-id }
      (merge app { compatibility-score: score })
    )
    (ok true)
  )
)

;; Toggle app active status
(define-public (toggle-app-status (app-id uint))
  (let
    (
      (app (unwrap! (map-get? mobile-apps { app-id: app-id }) ERR-APP-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get developer app))) ERR-NOT-AUTHORIZED)

    (map-set mobile-apps
      { app-id: app-id }
      (merge app { is-active: (not (get is-active app)) })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get app details
(define-read-only (get-app (app-id uint))
  (map-get? mobile-apps { app-id: app-id })
)

;; Get app usage statistics
(define-read-only (get-app-usage-stats (app-id uint))
  (map-get? app-usage-stats { app-id: app-id })
)

;; Get version details
(define-read-only (get-version-details (app-id uint) (version (string-ascii 20)))
  (map-get? app-versions { app-id: app-id, version: version })
)

;; Get developer apps
(define-read-only (get-developer-apps (developer principal))
  (map-get? developer-apps { developer: developer })
)

;; Get next app ID
(define-read-only (get-next-app-id)
  (var-get next-app-id)
)

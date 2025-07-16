;; Security Coordination Contract
;; Coordinates mobile security protocols and policies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-POLICY-NOT-FOUND (err u401))
(define-constant ERR-INCIDENT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-SEVERITY (err u403))
(define-constant ERR-INVALID-INPUT (err u404))

;; Data Variables
(define-data-var next-policy-id uint u1)
(define-data-var next-incident-id uint u1)

;; Data Maps
(define-map security-policies
  { policy-id: uint }
  {
    name: (string-ascii 50),
    policy-type: (string-ascii 30),
    description: (string-ascii 200),
    enforcement-level: uint,
    is-active: bool,
    created-by: principal,
    created-at: uint,
    last-updated: uint
  }
)

(define-map security-incidents
  { incident-id: uint }
  {
    app-id: uint,
    incident-type: (string-ascii 50),
    severity: uint,
    description: (string-ascii 200),
    status: (string-ascii 20),
    reported-by: principal,
    reported-at: uint,
    resolved-at: (optional uint),
    resolution-notes: (optional (string-ascii 200))
  }
)

(define-map app-security-compliance
  { app-id: uint }
  {
    compliance-score: uint,
    last-audit: uint,
    security-level: uint,
    encryption-status: bool,
    authentication-method: (string-ascii 30),
    policy-violations: uint
  }
)

(define-map authentication-configs
  { app-id: uint }
  {
    auth-method: (string-ascii 30),
    multi-factor: bool,
    session-timeout: uint,
    password-policy: (string-ascii 100),
    biometric-enabled: bool,
    last-updated: uint
  }
)

;; Public Functions

;; Create security policy
(define-public (create-security-policy (name (string-ascii 50)) (policy-type (string-ascii 30)) (description (string-ascii 200)) (enforcement-level uint))
  (let
    (
      (policy-id (var-get next-policy-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (len name) u51) ERR-INVALID-INPUT)
    (asserts! (< (len policy-type) u31) ERR-INVALID-INPUT)
    (asserts! (< (len description) u201) ERR-INVALID-INPUT)
    (asserts! (<= enforcement-level u5) ERR-INVALID-INPUT)

    (map-set security-policies
      { policy-id: policy-id }
      {
        name: name,
        policy-type: policy-type,
        description: description,
        enforcement-level: enforcement-level,
        is-active: true,
        created-by: tx-sender,
        created-at: block-height,
        last-updated: block-height
      }
    )

    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

;; Report security incident
(define-public (report-incident (app-id uint) (incident-type (string-ascii 50)) (severity uint) (description (string-ascii 200)))
  (let
    (
      (incident-id (var-get next-incident-id))
    )
    (asserts! (< (len incident-type) u51) ERR-INVALID-INPUT)
    (asserts! (< (len description) u201) ERR-INVALID-INPUT)
    (asserts! (<= severity u5) ERR-INVALID-SEVERITY)

    (map-set security-incidents
      { incident-id: incident-id }
      {
        app-id: app-id,
        incident-type: incident-type,
        severity: severity,
        description: description,
        status: "open",
        reported-by: tx-sender,
        reported-at: block-height,
        resolved-at: none,
        resolution-notes: none
      }
    )

    ;; Update app compliance score based on incident severity
    (match (map-get? app-security-compliance { app-id: app-id })
      compliance
      (let
        (
          (penalty (if (>= severity u4) u20 (if (>= severity u3) u10 u5)))
          (new-score (if (>= (get compliance-score compliance) penalty)
                        (- (get compliance-score compliance) penalty)
                        u0))
        )
        (map-set app-security-compliance
          { app-id: app-id }
          (merge compliance {
            compliance-score: new-score,
            policy-violations: (+ (get policy-violations compliance) u1)
          })
        )
      )
      ;; Create initial compliance record if none exists
      (map-set app-security-compliance
        { app-id: app-id }
        {
          compliance-score: u80,
          last-audit: block-height,
          security-level: u1,
          encryption-status: false,
          authentication-method: "basic",
          policy-violations: u1
        }
      )
    )

    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

;; Resolve security incident
(define-public (resolve-incident (incident-id uint) (resolution-notes (string-ascii 200)))
  (let
    (
      (incident (unwrap! (map-get? security-incidents { incident-id: incident-id }) ERR-INCIDENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (len resolution-notes) u201) ERR-INVALID-INPUT)

    (map-set security-incidents
      { incident-id: incident-id }
      (merge incident {
        status: "resolved",
        resolved-at: (some block-height),
        resolution-notes: (some resolution-notes)
      })
    )
    (ok true)
  )
)

;; Update app security compliance
(define-public (update-compliance (app-id uint) (compliance-score uint) (security-level uint) (encryption-status bool) (auth-method (string-ascii 30)))
  (let
    (
      (existing-compliance (map-get? app-security-compliance { app-id: app-id }))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= compliance-score u100) ERR-INVALID-INPUT)
    (asserts! (<= security-level u5) ERR-INVALID-INPUT)
    (asserts! (< (len auth-method) u31) ERR-INVALID-INPUT)

    (map-set app-security-compliance
      { app-id: app-id }
      {
        compliance-score: compliance-score,
        last-audit: block-height,
        security-level: security-level,
        encryption-status: encryption-status,
        authentication-method: auth-method,
        policy-violations: (default-to u0 (get policy-violations existing-compliance))
      }
    )
    (ok true)
  )
)

;; Configure authentication
(define-public (configure-authentication (app-id uint) (auth-method (string-ascii 30)) (multi-factor bool) (session-timeout uint) (password-policy (string-ascii 100)) (biometric-enabled bool))
  (begin
    (asserts! (< (len auth-method) u31) ERR-INVALID-INPUT)
    (asserts! (< (len password-policy) u101) ERR-INVALID-INPUT)
    (asserts! (> session-timeout u0) ERR-INVALID-INPUT)

    (map-set authentication-configs
      { app-id: app-id }
      {
        auth-method: auth-method,
        multi-factor: multi-factor,
        session-timeout: session-timeout,
        password-policy: password-policy,
        biometric-enabled: biometric-enabled,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

;; Update security policy
(define-public (update-policy (policy-id uint) (description (string-ascii 200)) (enforcement-level uint))
  (let
    (
      (policy (unwrap! (map-get? security-policies { policy-id: policy-id }) ERR-POLICY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (len description) u201) ERR-INVALID-INPUT)
    (asserts! (<= enforcement-level u5) ERR-INVALID-INPUT)

    (map-set security-policies
      { policy-id: policy-id }
      (merge policy {
        description: description,
        enforcement-level: enforcement-level,
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Toggle policy active status
(define-public (toggle-policy-status (policy-id uint))
  (let
    (
      (policy (unwrap! (map-get? security-policies { policy-id: policy-id }) ERR-POLICY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set security-policies
      { policy-id: policy-id }
      (merge policy { is-active: (not (get is-active policy)) })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get security policy
(define-read-only (get-security-policy (policy-id uint))
  (map-get? security-policies { policy-id: policy-id })
)

;; Get security incident
(define-read-only (get-security-incident (incident-id uint))
  (map-get? security-incidents { incident-id: incident-id })
)

;; Get app security compliance
(define-read-only (get-app-compliance (app-id uint))
  (map-get? app-security-compliance { app-id: app-id })
)

;; Get authentication configuration
(define-read-only (get-auth-config (app-id uint))
  (map-get? authentication-configs { app-id: app-id })
)

;; Get next policy ID
(define-read-only (get-next-policy-id)
  (var-get next-policy-id)
)

;; Get next incident ID
(define-read-only (get-next-incident-id)
  (var-get next-incident-id)
)

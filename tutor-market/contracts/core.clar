;; TutorChain Core: Tokenized Peer-to-Peer Tutoring Marketplace
;; SPDX-License-Identifier: MIT

;; Trait definition for fungible token
(define-trait ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-status (err u409))
(define-constant err-invalid-input (err u400))
(define-constant platform-fee-bps u500)
;; Session statuses
(define-constant STATUS-SCHEDULED u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-PAID u4)
(define-constant STATUS-CANCELLED u5)



;; Data Maps
(define-map user-roles { user: principal } { is-student: bool, is-tutor: bool })

(define-map tutor-profiles
  { tutor: principal }
  {
    bio: (string-utf8 500),
    hourly-rate: uint,
    subjects: (list 5 uint),
    total-sessions: uint,
    active: bool
  }
)

(define-map tutor-reputation
  { tutor: principal }
  {
    rating-sum: uint,
    rating-count: uint,
    completion-rate: uint
  }
)

(define-map subjects
  { subject-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 200)
  }
)

(define-map sessions
  { session-id: uint }
  {
    student: principal,
    tutor: principal,
    subject-id: uint,
    scheduled-start: uint,
    duration-minutes: uint,
    session-amount: uint,
    status: uint
  }
)


(define-data-var session-counter uint u0)

;; Registration
(define-public (register-as-student)
  (let ((current-role (default-to { is-student: false, is-tutor: false }
                                  (map-get? user-roles { user: tx-sender }))))
    (ok (map-set user-roles 
         { user: tx-sender }
         { is-student: true, is-tutor: (get is-tutor current-role) }))
  )
)

(define-public (register-as-tutor (bio (string-utf8 500)) (hourly-rate uint) (subjects-ids (list 5 uint)))
  (begin
    (asserts! (> hourly-rate u0) err-invalid-input)
    (let ((current-role (default-to { is-student: false, is-tutor: false }
                                    (map-get? user-roles { user: tx-sender }))))
      (map-set user-roles 
        { user: tx-sender }
        { is-student: (get is-student current-role), is-tutor: true }))
    (ok (map-set tutor-profiles
         { tutor: tx-sender }
         {
           bio: bio,
           hourly-rate: hourly-rate,
           subjects: subjects-ids,
           total-sessions: u0,
           active: true
         }))
  )
)

;; Schedule a session

(define-public (schedule-session (tutor principal) (subject-id uint) (scheduled-start uint) (duration-minutes uint) (token <ft-trait>))
  (let (
        (tutor-data (unwrap! (map-get? tutor-profiles { tutor: tutor }) err-not-found))
        (hourly-rate (get hourly-rate tutor-data))
        (session-id (var-get session-counter))
        (total-amount (/ (* hourly-rate duration-minutes) u60))
  )
    (asserts! (> scheduled-start stacks-block-height) err-invalid-input)
    (asserts! (> duration-minutes u0) err-invalid-input)
    (asserts! (get active tutor-data) err-invalid-input)

    (as-contract
      (try! (contract-call? token transfer total-amount tx-sender (contract-of token) none))
    )

    (map-set sessions
      { session-id: session-id }
      {
        student: tx-sender,
        tutor: tutor,
        subject-id: subject-id,
        scheduled-start: scheduled-start,
        duration-minutes: duration-minutes,
        session-amount: total-amount,
        status: STATUS-SCHEDULED
      })

    (var-set session-counter (+ session-id u1))

    (print { event: "session-scheduled", session-id: session-id, student: tx-sender, tutor: tutor })

    (ok session-id)
  )
)


(define-public (start-session (session-id uint))
  (let ((session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found)))
    (asserts! (is-eq (get tutor session) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status session) STATUS-SCHEDULED) err-invalid-status)

    (ok (map-set sessions
         { session-id: session-id }
         (merge session { status: STATUS-IN-PROGRESS })))
  )
)


(define-public (complete-session (session-id uint))
  (let (
        (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
        (tutor-data (unwrap! (map-get? tutor-profiles { tutor: (get tutor session) }) err-not-found)))
    (asserts! (is-eq (get tutor session) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status session) STATUS-IN-PROGRESS) err-invalid-status)

 (map-set sessions
  { session-id: session-id }
  (merge session { status: STATUS-COMPLETED }))


    (ok (map-set tutor-profiles
         { tutor: tx-sender }
         (merge tutor-data {
           total-sessions: (+ (get total-sessions tutor-data) u1)
         })))
  )
)

(define-public (cancel-session (session-id uint))
  (let ((session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found)))
    (asserts! (is-eq (get student session) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status session) STATUS-SCHEDULED) err-invalid-status)

    (map-set sessions { session-id: session-id } (merge session { status: STATUS-CANCELLED }))
    (print { event: "session-cancelled", session-id: session-id })
    (ok true)
  )
)


(define-public (release-payment (session-id uint) (rating uint) (token <ft-trait>))
  (let (
        (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
        (rep-data (default-to { rating-sum: u0, rating-count: u0, completion-rate: u10000 }
                             (map-get? tutor-reputation { tutor: (get tutor session) })))
        (platform-fee-amount (/ (* (get session-amount session) platform-fee-bps) u10000))
        (tutor-amount (- (get session-amount session) platform-fee-amount))
  )
    (asserts! (is-eq (get student session) tx-sender) err-not-authorized)
    (asserts! (is-eq (get status session) STATUS-COMPLETED) err-invalid-status)
    (asserts! (<= rating u100) err-invalid-input)

    (as-contract
      (begin
        (try! (contract-call? token transfer tutor-amount (contract-of token) (get tutor session) none))
        (try! (contract-call? token transfer platform-fee-amount (contract-of token) contract-owner none))
      )
    )

    (map-set tutor-reputation
      { tutor: (get tutor session) }
      {
        rating-sum: (+ (get rating-sum rep-data) rating),
        rating-count: (+ (get rating-count rep-data) u1),
        completion-rate: (get completion-rate rep-data)
      })

    (map-set sessions
      { session-id: session-id }
      (merge session { status: STATUS-PAID }))

    (print { event: "payment-released", session-id: session-id, tutor: (get tutor session), rating: rating })

    (ok true)
  )
)

;; Admin: Add or update a subject
(define-public (add-subject (subject-id uint) (name (string-utf8 50)) (description (string-utf8 200)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (ok (map-set subjects { subject-id: subject-id } { name: name, description: description }))
  )
)

;; Read-only functions
(define-read-only (get-session (session-id uint))
  (map-get? sessions { session-id: session-id })
)

(define-read-only (get-tutor-profile (tutor principal))
  (map-get? tutor-profiles { tutor: tutor })
)

(define-read-only (get-tutor-reputation (tutor principal))
  (map-get? tutor-reputation { tutor: tutor })
)

(define-read-only (get-subject (subject-id uint))
  (map-get? subjects { subject-id: subject-id })
)

(define-read-only (get-user-role (user principal))
  (map-get? user-roles { user: user })
)


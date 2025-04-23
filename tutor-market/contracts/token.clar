;; TutorChain Token: Token implementation for the TutorChain platform
;; Written in Clarity for the Stacks blockchain
;; SPDX-License-Identifier: MIT

;; Implements SIP-010 trait
(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the token balance of the specified principal
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of the token
    (get-total-supply () (response uint uint))

    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the token decimals
    (get-decimals () (response uint uint))

    ;; Get the token URI
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-stake (err u102))

;; Token definition
(define-fungible-token tutor-token)

;; Subject expertise tracking
(define-map tutor-expertise
  { tutor: principal, subject-id: uint }
  { level: uint }
)

;; Initialize token - Fix: Move to separate function to avoid execution at deploy time
(define-private (initialize-token)
  (begin
    ;; Only initialize if not already done
    (if (is-eq (ft-get-supply tutor-token) u0)
        (ft-mint? tutor-token u1000000000000 contract-owner)
        (ok true))
  )
)

;; Call initialize during contract deployment
(initialize-token)

;; SIP-010 Implementation

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (match (ft-transfer? tutor-token amount sender recipient)
      success (begin
        (print (default-to 0x memo))
        (ok true)
      )
      error (err error)
    )
  )
)

(define-read-only (get-name)
  (ok "TutorChain Token")
)

(define-read-only (get-symbol)
  (ok "TCT")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance tutor-token who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply tutor-token))
)

(define-read-only (get-token-uri)
  (ok (some u"https://tutorchain.io/token-metadata.json"))
)

;; Token admin functions

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (ft-mint? tutor-token amount recipient)
      success (ok true)
      error (err error)
    )
  )
)

;; Expertise token functions

(define-public (award-expertise (tutor principal) (subject-id uint) (points uint))
  (let
    ((current-expertise (default-to { level: u0 }
                                   (map-get? tutor-expertise { tutor: tutor, subject-id: subject-id })))
     (new-level (+ (get level current-expertise) points)))
    
    ;; Only the contract owner can award expertise
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (ok (map-set tutor-expertise
         { tutor: tutor, subject-id: subject-id }
         { level: new-level }
    ))
  )
)

;; Staking mechanism
(define-map stakes
  { tutor: principal }
  { amount: uint }
)

(define-public (stake (amount uint))
  (let
    ((current-stake (default-to { amount: u0 }
                              (map-get? stakes { tutor: tx-sender }))))
    
    ;; Transfer tokens to contract
    (try! (transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update stake
    (ok (map-set stakes
      { tutor: tx-sender }
      { amount: (+ (get amount current-stake) amount) }
    ))
  )
)

(define-public (unstake (amount uint))
  (let
    ((current-stake (default-to { amount: u0 }
                              (map-get? stakes { tutor: tx-sender }))))
    
    ;; Verify sufficient stake
    (asserts! (>= (get amount current-stake) amount) err-insufficient-stake)
    
    ;; Return tokens to tutor
    (try! (as-contract (transfer amount (as-contract tx-sender) tx-sender none)))
    
    ;; Update stake
    (ok (map-set stakes
      { tutor: tx-sender }
      { amount: (- (get amount current-stake) amount) }
    ))
  )
)

;; Read-only functions

(define-read-only (get-expertise (tutor principal) (subject-id uint))
  (default-to { level: u0 }
           (map-get? tutor-expertise { tutor: tutor, subject-id: subject-id }))
)

(define-read-only (get-stake (tutor principal))
  (default-to { amount: u0 }
           (map-get? stakes { tutor: tutor }))
)
;; DeFi Lending Platform Smart Contract

;; Errors
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u104))

;; Storage
(define-map loans 
  {user: principal, loan-id: uint}
  {
    amount: uint,
    collateral: uint,
    interest-rate: uint,
    start-time: uint,
    is-active: bool
  }
)

(define-map user-loans 
  principal 
  (list 10 uint)
)

;; Variables
(define-data-var loan-counter uint u0)
(define-data-var min-collateral-ratio uint u150) ;; 150% minimum
(define-data-var liquidation-threshold uint u125) ;; 125% threshold

;; Token Contracts (to be replaced with actual token contract principals)
(define-constant LENDING-TOKEN .my-lending-token)
(define-constant COLLATERAL-TOKEN .my-collateral-token)

;; Borrow Function
(define-public (borrow (amount uint) (collateral-amount uint))
  (let (
    (user tx-sender)
    (loan-id (+ (var-get loan-counter) u1))
    (collateral-ratio (/ (* collateral-amount u100) amount))
  )
  (begin
    ;; Check collateral ratio meets minimum requirement
    (asserts! (>= collateral-ratio (var-get min-collateral-ratio)) 
      (err ERR-INSUFFICIENT-COLLATERAL))
    
    ;; Transfer collateral to contract
    (try! (contract-call? COLLATERAL-TOKEN transfer 
      collateral-amount 
      user 
      (as-contract tx-sender) 
      none))
    
    ;; Calculate interest rate based on collateral ratio (example)
    (let (
      (interest-rate (calculate-interest-rate collateral-ratio))
    )
      ;; Store loan details
      (map-set loans 
        {user: user, loan-id: loan-id}
        {
          amount: amount,
          collateral: collateral-amount,
          interest-rate: interest-rate,
          start-time: block-height,
          is-active: true
        }
      )
      
      ;; Update user's loan list
      (let (
        (current-loans (default-to (list) (map-get? user-loans user)))
        (updated-loans (unwrap! (as-max-len? (append current-loans loan-id) u10) 
          (err ERR-UNAUTHORIZED)))
      )
        (map-set user-loans user updated-loans)
      )
      
      ;; Increment loan counter
      (var-set loan-counter loan-id)
      
      ;; Transfer borrowed amount to user
      (try! (contract-call? LENDING-TOKEN mint amount user))
      
      (ok loan-id)
    )
  ))

;; Repay Loan Function
(define-public (repay-loan (loan-id uint))
  (let (
    (user tx-sender)
    (loan (unwrap! (map-get? loans {user: user, loan-id: loan-id}) 
            (err ERR-LOAN-NOT-FOUND)))
    (total-repayment (calculate-total-repayment loan))
  )
  (begin
    ;; Check user has sufficient balance
    (asserts! (>= (unwrap-panic (contract-call? LENDING-TOKEN get-balance user)) 
                total-repayment) 
      (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Burn repayment tokens
    (try! (contract-call? LENDING-TOKEN burn total-repayment user))
    
    ;; Return collateral
    (try! (as-contract 
      (contract-call? COLLATERAL-TOKEN transfer 
        (get collateral loan) 
        tx-sender 
        user 
        none)))
    
    ;; Mark loan as inactive
    (map-set loans 
      {user: user, loan-id: loan-id}
      (merge loan {is-active: false})
    )
    
    (ok true)
  ))

;; Liquidation Function
(define-public (liquidate (user principal) (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans {user: user, loan-id: loan-id}) 
            (err ERR-LOAN-NOT-FOUND)))
    (current-collateral-ratio (calculate-current-collateral-ratio loan))
  )
  (begin
    ;; Check if liquidation is allowed
    (asserts! (<= current-collateral-ratio (var-get liquidation-threshold))
      (err ERR-LIQUIDATION-NOT-ALLOWED))
    
    ;; Transfer a portion of collateral to liquidator
    (try! (as-contract 
      (contract-call? COLLATERAL-TOKEN transfer 
        (/ (get collateral loan) u2) ;; Example: 50% of collateral 
        tx-sender 
        (var-get liquidator) 
        none)))
    
    ;; Mark loan as inactive
    (map-set loans 
      {user: user, loan-id: loan-id}
      (merge loan {is-active: false})
    )
    
    (ok true)
  ))

;; Helper Functions
(define-read-only (calculate-interest-rate (collateral-ratio uint))
  ;; Example: Lower interest rate for higher collateral ratio
  (if (>= collateral-ratio u200) 
    u5   ;; 5% interest for 200%+ collateral
    (if (>= collateral-ratio u150)
      u10  ;; 10% interest for 150-200% collateral
      u15  ;; 15% interest for lower collateral
    )
  )
)

(define-read-only (calculate-current-collateral-ratio (loan {amount: uint, collateral: uint}))
  ;; Calculate current collateral ratio
  (/ (* (get collateral loan) u100) (get amount loan))
)

(define-read-only (calculate-total-repayment (loan {amount: uint, interest-rate: uint, start-time: uint}))
  ;; Calculate total repayment with simple interest
  (let (
    (principal (get amount loan))
    (interest-rate (get interest-rate loan))
    (time-passed (- block-height (get start-time loan)))
  )
    (+ principal (/ (* principal interest-rate time-passed) u10000))
  )
)

;; Initialize contract
(define-public (initialize)
  (begin
    ;; Set initial parameters
    (var-set min-collateral-ratio u150)
    (var-set liquidation-threshold u125)
    (ok true)
  )
)
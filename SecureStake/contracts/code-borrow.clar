(define-constant ERR-INSUFFICIENT-COLLATERAL (err u100))
(define-constant ERR-LOAN-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))

(define-map loans 
  {user: principal, loan-id: uint}
  {
    amount: uint,
    collateral: uint,
    interest-rate: uint,
    is-active: bool
  }
)

(define-map user-loans 
  principal 
  (list 10 uint)
)

(define-data-var loan-counter uint u0)
(define-data-var min-collateral-ratio uint u150)
(define-data-var liquidation-threshold uint u125)
(define-data-var liquidator principal tx-sender)

(define-public (transfer-collateral 
  (amount uint) 
  (sender principal) 
  (recipient principal)
)
  (ok true)
)

(define-public (mint-tokens (amount uint) (recipient principal))
  (ok true)
)

(define-public (get-balance (who principal))
  (ok u1000)
)

(define-public (burn-tokens (amount uint) (sender principal))
  (ok true)
)

(define-read-only (calculate-interest-rate (collateral-ratio uint))
  (if (>= collateral-ratio u200) 
    u5   
    (if (>= collateral-ratio u150)
      u10  
      u15  
    )
  )
)

(define-read-only (calculate-current-collateral-ratio (loan {amount: uint, collateral: uint}))
  (/ (* (get collateral loan) u100) (get amount loan))
)

(define-read-only (calculate-total-repayment (loan {amount: uint, interest-rate: uint}))
  (let (
    (principal (get amount loan))
    (interest-rate (get interest-rate loan))
  )
    (+ principal (/ (* principal interest-rate u10) u100))
  )
)

(define-public (borrow (amount uint) (collateral-amount uint))
  (let (
    (user tx-sender)
    (loan-id (+ (var-get loan-counter) u1))
    (collateral-ratio (/ (* collateral-amount u100) amount))
  )
    (begin
      (asserts! (>= collateral-ratio (var-get min-collateral-ratio)) 
        (err ERR-INSUFFICIENT-COLLATERAL))
      
      (unwrap! (transfer-collateral 
        collateral-amount 
        user 
        (as-contract tx-sender))
        (err ERR-TRANSFER-FAILED)
      )
      
      (let (
        (interest-rate (calculate-interest-rate collateral-ratio))
      )
        (map-set loans 
          {user: user, loan-id: loan-id}
          {
            amount: amount,
            collateral: collateral-amount,
            interest-rate: interest-rate,
            is-active: true
          }
        )
        
        (let (
          (current-loans (default-to (list) (map-get? user-loans user)))
          (updated-loans (unwrap! (as-max-len? (append current-loans loan-id) u10) 
            (err ERR-UNAUTHORIZED)))
        )
          (map-set user-loans user updated-loans)
        )
        
        (var-set loan-counter loan-id)
        
        (unwrap! (mint-tokens amount user)
          (err ERR-TRANSFER-FAILED)
        )
        
        (ok loan-id)
      )
    )
  )
)

(define-public (repay-loan (loan-id uint))
  (let (
    (user tx-sender)
    (loan (unwrap! (map-get? loans {user: user, loan-id: loan-id}) 
            (err ERR-LOAN-NOT-FOUND)))
    (total-repayment (calculate-total-repayment 
      {amount: (get amount loan), interest-rate: (get interest-rate loan)}))
  )
    (begin
      (asserts! (>= (unwrap-panic (get-balance user)) 
                  total-repayment) 
        (err ERR-INSUFFICIENT-BALANCE))
      
      (unwrap! (burn-tokens total-repayment user)
        (err ERR-TRANSFER-FAILED)
      )
      
      (unwrap! (as-contract 
        (transfer-collateral 
          (get collateral loan) 
          tx-sender 
          user))
        (err ERR-TRANSFER-FAILED)
      )
      
      (map-set loans 
        {user: user, loan-id: loan-id}
        (merge loan {is-active: false})
      )
      
      (ok true)
    )
  )
)

(define-public (liquidate (user principal) (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans {user: user, loan-id: loan-id}) 
            (err ERR-LOAN-NOT-FOUND)))
    (current-collateral-ratio (calculate-current-collateral-ratio 
      {amount: (get amount loan), collateral: (get collateral loan)}))
  )
    (begin
      (asserts! (<= current-collateral-ratio (var-get liquidation-threshold))
        (err ERR-LIQUIDATION-NOT-ALLOWED))
      
      (unwrap! (as-contract 
        (transfer-collateral 
          (/ (get collateral loan) u2)
          tx-sender 
          (var-get liquidator)))
        (err ERR-TRANSFER-FAILED)
      )
      
      (map-set loans 
        {user: user, loan-id: loan-id}
        (merge loan {is-active: false})
      )
      
      (ok true)
    )
  )
)

(define-public (initialize)
  (begin
    (var-set min-collateral-ratio u150)
    (var-set liquidation-threshold u125)
    (ok true)
  )
)
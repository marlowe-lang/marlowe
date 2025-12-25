theory MerkleInterpreter

imports MerkleTypes Core.Semantics
begin

section "Interpreter"

fun getAction :: "MCase \<Rightarrow> Action" where
  "getAction (Case action _) = action"
| "getAction (MerkleizedCase action _) = action"

fun getInputContent :: "MInput \<Rightarrow> Input" where 
  "getInputContent (NormalInput i) = i" 
| "getInputContent (MerkleizedInput i _ _) = i"

fun getContinuation :: "MInput \<Rightarrow> MCase \<Rightarrow> MContract option" where
  "getContinuation (NormalInput _) (Case _ continuation) = Some continuation" 
| "getContinuation (MerkleizedInput _ inputContinuationHash continuation)  (MerkleizedCase _ continuationHash)
    = (if inputContinuationHash = continuationHash 
       then Some continuation 
       else None
      )" 
| "getContinuation _ _ = None"

subsection "Reduce contract Step"

\<comment> \<open>The only difference with ReduceStepResult is the MContract instead of Contract\<close>
datatype ReduceStepMResult = Reduced ReduceWarning ReduceEffect State MContract
                          | NotReduced
                          | AmbiguousTimeIntervalReductionError

fun reduceMContractStep :: "Environment \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> ReduceStepMResult" where
"reduceMContractStep _ state Close =
  (case refundOne (accounts state) of
     Some ((party, token, money), newAccount) \<Rightarrow>
       let newState = state \<lparr> accounts := newAccount \<rparr> in
       Reduced ReduceNoWarning (ReduceWithPayment (Payment party (Party party) token money)) newState Close
   | None \<Rightarrow> NotReduced)" |
"reduceMContractStep env state (Pay accId payee token val cont) =
  (let amountToPay = evalValue env state val in
   if amountToPay \<le> 0
   then (let warning = ReduceNonPositivePay accId payee token amountToPay in
         Reduced warning ReduceNoPayment state cont)
   else (let balance = moneyInAccount accId token (accounts state);
             paidAmount = min balance amountToPay;
             newBalance = balance - paidAmount;
             newAccs = updateMoneyInAccount accId token newBalance (accounts state);
             warning = (if paidAmount < amountToPay
                        then ReducePartialPay accId payee token paidAmount amountToPay
                        else ReduceNoWarning) ;
            (payment, finalAccs) = giveMoney accId payee token paidAmount newAccs 
          in
         Reduced warning payment (state \<lparr> accounts := finalAccs \<rparr>) cont))" |
"reduceMContractStep env state (If obs cont1 cont2) =
  (let cont = (if evalObservation env state obs
               then cont1
               else cont2) in
   Reduced ReduceNoWarning ReduceNoPayment state cont)" |
"reduceMContractStep env state (When _ timeout cont) =
  (let (startTime, endTime) = timeInterval env in
   \<comment> \<open>if timeout in future – do not reduce\<close>
   if endTime < timeout then NotReduced
   \<comment> \<open>if timeout in the past – reduce to timeout continuation\<close>   
   else if timeout \<le> startTime then Reduced ReduceNoWarning ReduceNoPayment state cont
   \<comment> \<open> if timeout in the time range – issue an ambiguity error\<close>  
   else AmbiguousTimeIntervalReductionError)" |
"reduceMContractStep env state (Let valId val cont) =
  (let evaluatedValue = evalValue env state val;
       boundVals = boundValues state;
       newState = state \<lparr> boundValues := MList.insert valId evaluatedValue boundVals \<rparr>;
       warn = case lookup valId boundVals of
                Some oldVal \<Rightarrow> ReduceShadowing valId oldVal evaluatedValue
              | None \<Rightarrow> ReduceNoWarning 
   in Reduced warn ReduceNoPayment newState cont)" |
"reduceMContractStep env state (Assert obs cont) =
  (let warning = if evalObservation env state obs
                 then ReduceNoWarning
                 else ReduceAssertionFailed
   in Reduced warning ReduceNoPayment state cont)"

subsection "Evaluation size"

text \<open>This function gives the notion of size for an evaluation. It is used to show that reductionMLoop
terminates.\<close>
fun evalSize :: "State \<Rightarrow> MContract \<Rightarrow> nat" where
"evalSize sta cont = length (accounts sta) + 2 * (size cont)"

lemma reduceMContractStepReducesSize :
  "reduceMContractStep env sta c = Reduced twa tef nsta nc \<Longrightarrow>
     (evalSize nsta nc) < (evalSize sta c)"
  sorry


subsection "Reduce contract until quiescent"


\<comment> \<open>The only difference with ReduceResult is the MContract instead of Contract\<close>

datatype ReduceMResult 
  = ContractQuiescent bool "ReduceWarning list" "Payment list" State MContract
  | RRAmbiguousTimeIntervalError


function (sequential) reductionMLoop :: "bool \<Rightarrow> Environment \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> ReduceWarning list \<Rightarrow>
                                        Payment list \<Rightarrow> ReduceMResult" where
"reductionMLoop reduced env state contract warnings payments =
  (case reduceMContractStep env state contract of
     Reduced warning effect newState ncontract \<Rightarrow>
       let newWarnings = (if warning = ReduceNoWarning
                          then warnings
                          else warning # warnings) in
       let newPayments = (case effect of
                            ReduceWithPayment payment \<Rightarrow> payment # payments
                          | ReduceNoPayment \<Rightarrow> payments) in
       reductionMLoop True env newState ncontract newWarnings newPayments
   | AmbiguousTimeIntervalReductionError \<Rightarrow> RRAmbiguousTimeIntervalError
   | NotReduced \<Rightarrow> ContractQuiescent reduced (rev warnings) (rev payments) state contract)"
  by pat_completeness auto
termination reductionMLoop
  apply (relation "measure (\<lambda>(_, (_, (state, (contract, _)))) . evalSize state contract)")  
  using reduceMContractStepReducesSize by auto


fun reduceMContractUntilQuiescent :: "Environment \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> ReduceMResult" where
"reduceMContractUntilQuiescent env state contract = reductionMLoop False env state contract [] []"

subsection "Apply input"

datatype ApplyAction = AppliedAction ApplyWarning State
                     | NotAppliedAction

datatype ApplyMResult = Applied ApplyWarning State MContract
                      | ApplyNoMatchError

fun applyAction :: "Environment \<Rightarrow> State \<Rightarrow> Input \<Rightarrow> Action \<Rightarrow> ApplyAction" where 
 "applyAction env state (IDeposit accId1 party1 tok1 amount) (Deposit accId2 party2 tok2 val) = 
   (if accId1 = accId2 & party1 = party2 & tok1 = tok2 & amount = evalValue env state val  
    then let warning = if amount > 0 then ApplyNoWarning 
                       else  ApplyNonPositiveDeposit party2 accId2 tok2 amount;
             newAccounts = addMoneyToAccount accId1 tok1 amount (accounts state);
             newState = state \<lparr> accounts := newAccounts\<rparr>
         in AppliedAction warning newState
    else NotAppliedAction 
   )"
|"applyAction _ state (IChoice choId1 choice) (Choice choId2 bounds) = 
  (if choId1 = choId2 & inBounds choice bounds
    then let newState = state \<lparr> choices := MList.insert choId1 choice (choices state) \<rparr>
         in AppliedAction ApplyNoWarning newState
    else NotAppliedAction
  )" 
|"applyAction env state INotify (Notify obs) = 
  (if evalObservation env state obs 
    then AppliedAction ApplyNoWarning state 
    else  NotAppliedAction
 )"
|"applyAction _ _ (IChoice _ _) (Deposit _ _ _ _) = NotAppliedAction"
|"applyAction _ _ (IChoice _ _) (Notify _) = NotAppliedAction"
|"applyAction _ _ INotify (Deposit _ _ _ _) = NotAppliedAction"
|"applyAction _ _ INotify (Choice _ _) = NotAppliedAction"
|"applyAction _ _ (IDeposit _ _ _ _) (Choice _ _) = NotAppliedAction"
|"applyAction _ _ (IDeposit _ _ _ _) (Notify _) = NotAppliedAction"


fun applyMCases ::  "Environment \<Rightarrow> State \<Rightarrow> MInput \<Rightarrow> MCase list \<Rightarrow> ApplyMResult" where
"applyMCases _ _ _ [] = ApplyNoMatchError" |
"applyMCases env state input (headCase # tailCases) = (
  let inputContent = getInputContent input;
      action = getAction headCase;
      maybeContinuation = getContinuation input headCase 
  in (case applyAction env state inputContent action of 
      AppliedAction  warning newState \<Rightarrow> ApplyNoMatchError
    | NotAppliedAction \<Rightarrow> applyMCases env state input tailCases)
  )
"

fun applyMInput :: "Environment \<Rightarrow> State \<Rightarrow> MInput \<Rightarrow> MContract \<Rightarrow> ApplyMResult" where
"applyMInput env state input (When cases _ _) = applyMCases env state input cases" |
"applyMInput env state input c = ApplyNoMatchError"


subsection "Apply all inputs"

datatype ApplyAllMResult = 
  ApplyAllSuccess bool "TransactionWarning list" "Payment list" State MContract
| ApplyAllNoMatchError
| ApplyAllAmbiguousTimeIntervalError
| ApplyAllHashMismatch 

 
fun applyAllMLoop :: "bool \<Rightarrow> Environment \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> MInput list \<Rightarrow>
                    TransactionWarning list \<Rightarrow> Payment list \<Rightarrow>
                    ApplyAllMResult" where
"applyAllMLoop contractChanged env state contract inpts warnings payments =
   (case reduceMContractUntilQuiescent env state contract of
      RRAmbiguousTimeIntervalError \<Rightarrow> ApplyAllAmbiguousTimeIntervalError
    | ContractQuiescent reduced reduceWarns pays curState cont \<Rightarrow>
       (case inpts of
          Nil \<Rightarrow> ApplyAllSuccess (contractChanged \<or> reduced) (warnings @ (convertReduceWarnings reduceWarns))
                                 (payments @ pays) curState cont
        | Cons input rest \<Rightarrow>
           (case applyMInput env curState input cont of
              Applied applyWarn newState appliedCont \<Rightarrow>
                  applyAllMLoop True env newState appliedCont rest
                               (warnings @ (convertReduceWarnings reduceWarns)
                                         @ (convertApplyWarning applyWarn))
                               (payments @ pays)
            | ApplyNoMatchError \<Rightarrow> ApplyAllNoMatchError)))"


fun applyAllMInputs :: "Environment \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> MInput list \<Rightarrow>
                 ApplyAllMResult" where
"applyAllMInputs env state contract inps = applyAllMLoop False env state contract inps Nil Nil"

subsection "Compute transaction"


record MTransaction = interval :: TimeInterval
                      inputs :: "MInput list"


datatype TransactionError = TEAmbiguousTimeIntervalError
                          | TEApplyNoMatchError
                          | TEIntervalError IntervalError
                          | TEUselessTransaction
                          | TEHashMismatch

record TransactionOutputRecord = txOutWarnings :: "TransactionWarning list"
                                 txOutPayments :: "Payment list"
                                 txOutState :: State
                                 txOutContract :: MContract


datatype TransactionOutput 
  = TransactionOutput TransactionOutputRecord
  | TransactionError TransactionError

fun computeMTransaction :: "MTransaction \<Rightarrow> State \<Rightarrow> MContract \<Rightarrow> TransactionOutput" where
"computeMTransaction tx state contract =
  (let inps = inputs tx in
   case fixInterval (interval tx) state of
     IntervalTrimmed env fixSta \<Rightarrow>
       (case applyAllMInputs env fixSta contract inps of
          ApplyAllSuccess reduced warnings payments newState cont \<Rightarrow>
            if ((\<not> reduced) \<and> ((contract \<noteq> Close) \<or> (accounts state = [])))
            then TransactionError TEUselessTransaction
            else TransactionOutput \<lparr> txOutWarnings = warnings
                                   , txOutPayments = payments
                                   , txOutState = newState
                                   , txOutContract = cont \<rparr>
        | ApplyAllNoMatchError \<Rightarrow> TransactionError TEApplyNoMatchError
        | ApplyAllAmbiguousTimeIntervalError \<Rightarrow> TransactionError TEAmbiguousTimeIntervalError
        | ApplyAllHashMismatch => TransactionError TEHashMismatch        
       )        
     | IntervalError error \<Rightarrow> TransactionError (TEIntervalError error))"
end
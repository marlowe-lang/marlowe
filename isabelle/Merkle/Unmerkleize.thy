theory Unmerkleize
  imports MerkleTypes "HOL-Library.Finite_Map" "HOL-Library.Monad_Syntax"
begin

section "MerkleMap"
text \<open>The Unmerkleize theory is responsible for reversing the process of contract merkleization.
Its implementation involves looking up each sub-contract's continuation from a Merkle map. \<close>

type_synonym MerkleMap = "(ByteString, MContract) fmap"

subsection "Size"

text "The following functions provide the notion of size to a Merkleized Contract, Case and MerkleMap.
They are used to prove the termination of the unmerkleize function "
fun mcontract_size :: "MContract \<Rightarrow> nat"
and mcase_size :: "MCase \<Rightarrow> nat"
where
 "mcontract_size Close = 1"
|"mcontract_size (Pay _ _ _ _ cont) = 1 + mcontract_size cont"
|"mcontract_size (Let _ _ cont) = 1 + mcontract_size cont"
|"mcontract_size (Assert _ cont) = 1 + mcontract_size cont"
|"mcontract_size (If _ trueCont falseCont) = 1 + mcontract_size trueCont + mcontract_size falseCont"
|"mcontract_size (When [] _ cont) = 1 + mcontract_size cont"
|"mcontract_size (When (c#cs) t cont) = mcase_size c + mcontract_size ((When cs t cont))"
|"mcase_size (Case _ cont) = 1 + mcontract_size cont "
|"mcase_size (MerkleizedCase _ _) = 1 "

fun addMerkleMapSize :: "(ByteString \<times> MContract) \<Rightarrow> nat \<Rightarrow> nat" where
"addMerkleMapSize e a = mcontract_size (snd e) + a"


fun merkleMap_size :: "MerkleMap \<Rightarrow> nat" where
"merkleMap_size m = ffold addMerkleMapSize 0 (fset_of_fmap m)"

lemma cont_size_lt_when [simp] : "mcontract_size cont < mcontract_size (When cases timeout cont)"
  by (induction cases) simp_all

lemma case_size_lt_when [simp]: "c \<in> set cases \<Longrightarrow> mcase_size c < mcontract_size (When cases timeout cont)"
proof (induction cases)
  case Nil
  then show ?case by simp
next
  case (Cons a cases)
  then show ?case
    by (smt (verit, del_insts) Groups.ab_semigroup_add_class.add.commute Unmerkleize.mcontract_size.simps(7) cont_size_lt_when add_lessD1 nat_add_left_cancel_less set_ConsD)
qed

interpretation comp_fun_commute "addMerkleMapSize"
  by unfold_locales auto

lemma merkleMap_size_distrib_drop:
  assumes "fmlookup m k = Some c"
  shows "merkleMap_size m = mcontract_size c + merkleMap_size (fmdrop k m)"
proof -
  note assms
  moreover obtain m' where "fmdrop k m = m'"
    by simp
  moreover have "\<forall>v. (k, v) |\<notin>| fset_of_fmap m'"
    using calculation by fastforce
  
  moreover have "m = fmupd k c m'"
    using calculation fmlookup_inject by fastforce

  moreover have "fset_of_fmap m = finsert (k,c) (fset_of_fmap m')"
    using calculation
     apply auto     
     by presburger (metis Option.option.inject)

  ultimately show ?thesis
    by auto    
qed

subsection "Unmerkleize"

text "We define the unmerkleize function for contract and case together as they are mutually recursive.
Each function takes as input a map of continuations and the merkleized contract or case, and may return
 the unmerkleized version if all the continuations are present in the map
"
term those
function (sequential) unmerkleize :: "MerkleMap \<Rightarrow> MContract \<Rightarrow> Contract option"
and unmerkleizeCase :: "MerkleMap \<Rightarrow> MCase \<Rightarrow> Case option"
where
\<comment> \<open>Close is the base case\<close>
 "unmerkleize _ MContract.Close = Some Contract.Close"
\<comment> \<open>Pay, Let, Assert and If recursively unmerkleize the continuations\<close>
|"unmerkleize merkleConts (MContract.Pay accId payee tok val cont) =
  map_option (Contract.Pay accId payee tok val) (unmerkleize merkleConts cont)"
|"unmerkleize merkleConts (MContract.Let valId val cont) =
  map_option (Contract.Let valId val) (unmerkleize merkleConts cont)"
|"unmerkleize merkleConts (MContract.Assert obs cont) =
  map_option (Contract.Assert obs) (unmerkleize merkleConts cont)"
|"unmerkleize merkleConts (MContract.If obs contTrue contFalse) =
  (let
    mContTrue = unmerkleize merkleConts contTrue;
    mContFalse = unmerkleize merkleConts contFalse
  in
     case (mContTrue, mContFalse) of
      (Some t, Some f) \<Rightarrow> Some (Contract.If obs t f)
     |(_, _) \<Rightarrow> None
  )
 "
\<comment> \<open>For the \<^emph>\<open>When\<close> contract we unmerkleize the timeout continuation and the cases\<close>
|"unmerkleize merkleConts (MContract.When cases timeout cont)  =
  (let
    mCont = unmerkleize merkleConts cont;
    \<comment> \<open>\<^emph>\<open>those:: a option list \<Rightarrow> 'a list option\<close> makes sure that all the cases succeed\<close>
    mCases = those (map (unmerkleizeCase merkleConts) cases)
    
   in
    case (mCases, mCont) of
      (Some cs, Some c) \<Rightarrow> Some (Contract.When cs timeout c)
     |(_, _) \<Rightarrow> None
  )
  "
\<comment> \<open>For the normal case we just unmerkleize the continuation\<close>
|"unmerkleizeCase merkleConts (MCase.Case action cont) =
  map_option (Case.Case action) (unmerkleize merkleConts cont)"
\<comment> \<open>For the merkleized case, we check if the continuation hash is present in the map of continuations.
    If it is, we continue the unmerkleization process by dropping the case from the map. 
    Removing contHash from the map ensures that there are no loops (which is needed to prove termination).
    Note that we are not verifying that the contract continuation hashes to contHash. 
    That would provide a higher level of assurance since it not only prevents loops but also
    ensures authenticity. Eventually, when we execute the merkleized contract on the blockchain,
    it is necessary to perform this authenticity check. However, in this context, relaxing the 
    assumption that contHash corresponds to the contract continuation allows for greater flexibility 
    in the unmerkleization process and contract creation\<close>
|"unmerkleizeCase merkleConts (MCase.MerkleizedCase action contHash) =
  ( let
      cont' = fmlookup merkleConts contHash >>= unmerkleize (fmdrop contHash merkleConts)
    in
      map_option (Case.Case action) cont'
  )
   "
  by pat_completeness auto
termination
\<comment> \<open>To prove that the function terminates we use a measure related to the number of continuations. 
At each recursive call, either the measure of the continuation gets smaller, or the measure of all 
possible continuations (from the map) get smaller\<close>
  apply (relation "measure
                    (\<lambda>t. case t of
                      Inl (dict, cont) \<Rightarrow> merkleMap_size dict + mcontract_size cont
                      |Inr (dict, case') \<Rightarrow> merkleMap_size dict + mcase_size case'
                    )")
   using merkleMap_size_distrib_drop by auto
  

end
theory MerkleTypes

imports Core.SemanticsTypes
begin

section "Types"

datatype MCase = Case Action MContract
             | MerkleizedCase Action ByteString
and MContract = Close
             | Pay AccountId Payee Token Value MContract
             | If Observation MContract MContract
             | When "MCase list" Timeout MContract
             | Let ValueId Value MContract
             | Assert Observation MContract

datatype MInput = NormalInput Input
                | MerkleizedInput Input ByteString MContract 

end
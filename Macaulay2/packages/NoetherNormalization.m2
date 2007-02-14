--=========================================================================--

newPackage(
     "NoetherNormalization",
     Version => "0.1", 
     Date => "Jan 18, 2007",
     Authors => {
	  {Name => "Nathaniel Stapleton", Email => "nstaple2@math.uiuc.edu"},
	  {Name => "Bart Snapp", Email => "snapp@math.uiuc.edu", HomePage => "http://www.math.uiuc.edu/~snapp/"}
	  },
     Headline => "computes Noether Normalization",
     DebuggingMode => true
     )

-- The algorithm given here is based on A. Loger's algorithm as given
-- in "A Computational Proof of the Noether Normalization Lemma" LNCS
-- 357.

--=========================================================================--
     
export{noetherNormalization} -- if the new routines which you are adding have new
-- names, then they need to be exported; otherwise they should not be
-- exported
        
--=========================================================================--

integralSet = method();
integralSet(GroebnerBasis) := List => G -> (
     J = {};
     M := gens G;
     for i from 0 to numgens source M - 1 do ( -- check the gens of G to see if their leadMonomial is in a single variable
           if # support leadMonomial (M)_(0,i) === 1 then J = J | {support leadMonomial (M)_(0,i)} --checks how many vars are in the lead
           );
     J = unique flatten J; --note that according to the algorithm J is a set of integers (in fact indices), we choose to return the variables
     return J);
--=========================================
varPrep = method();
varPrep(GroebnerBasis) := Sequence => G -> (
     X := gens ring G; -- doesn't work because variables are backwards
     X = reverse X;
     M := gens G;
     U := {};
     V := {};
     for j from 0 to #X - 1 do (
      	  for i from 0 to numgens source M - 1 do ( -- going from zero to the number of gens of the gb - 1      
	       if isSubset(support (M)_(0,i),take(X,j+1)) and isSubset({X_j}, support (M)_(0,i)) then (
            	    V = V | {X_j};                -- repeatedly appending could be slow, try for ... list or while ... list
            	    break;   
		    );
               );     
	  if not isSubset({X_j},V) then U = U | {X_j};
      	  );
     (U,V)                        -- (x,y) = (U,V) ; (x,y) := (U,V) can be used by the caller if you return a sequence
     );       
--==================================================
lastCheck = method();
lastCheck(GroebnerBasis, ZZ) := Boolean => (G,d) -> (
     X := reverse gens ring G;
     M := gens G;
     i := 0;
     while i < min(d,numgens source M) and not isSubset(support M_(0,i),toList(X_0..X_(d-1))) do (
	  i = i+1;
	  );
     if i != d then return false
     else(
	  for j from d to #X-1 do (      
	       for p from 0 to numgens source M - 1 do (
		    if {X_j} == support leadTerm M_(0,p) then break;
                    if p == numgens source M - 1 then false
            	    );
               );
	  );
     true
     );
--==============================================


noetherPrime = method();
noetherPrime(Ideal,GroebnerBasis,List,List) := Sequence => (I,G,U,V) -> (
     R := ring I;
     done := false;
     X := U | V;
     f := map(R,R,reverse X);
     while done == false do ( 
--	  G = gb f(I); --we should not need to do this gb computation
	  J := integralSet(G);
	  V = apply(V, i -> f(i)); --there might be a faster way to do this, perhaps V={x_(#U)..x_(#U+#V-1)}
	  U = apply(U, i -> f(i)); -- might be faster to do U = {x_0..x_(#U-1)}
	  U = apply(U, i -> i + sum(V - set J)); --make sure V and J jive so that this makes sense, also in later version multiply the sum by a random in k
      	  --note that right now we can get stuck in an infinite loop as we aren't multiplying by a random
	  g := map(R,R,reverse(U|V));
	  h = g*f;
	  done = lastCheck(gb h I, #U);
	  if done then return((gens gb h I,h));
	  (U,V) = varPrep G;
      	  );
     );





-- If just running, skip this one.

noetherNotPrime = method();
noetherNotPrime(Ideal,GroebnerBasis,List,List) := Sequence => (I,G,U,V) -> (
     R := ring I;
     done := false;
     X := U | V;
     f := map(R,R,reverse X);
     XP := permutations gens R;
-- Some experimental code:
-- the problem is that the map doesn't seem to be really changing the vars...
R = QQ[x_4,x_3,x_2,x_1, MonomialOrder => Lex]; --the same ordering as in the paper
XP = permutations gens R
I =ideal(x_3^3*x_2^2)
(U,V) = varPrep(gb I)
for i from 1 to #XP-1 do (
     m = map(R,R,XP_i);
     (U,V) = varPrep(m gb I);
     if #U == dim I then break);
U
m
varPrep gb I   -- not any different
varPrep gb m I -- not any different
-- this may be a problem with varPrep.....



-- end experiment
     while done == false do ( --use of #U=dimI here and below must be replaced if I is not prime
--	  G = gb f(I); --we should not need to do this gb computation
	  J := integralSet(G);
	  V = apply(V, i -> f(i)); --there might be a faster way to do this, perhaps V={x_(#U)..x_(#U+#V-1)}
	  U = apply(U, i -> f(i)); -- might be faster to do U = {x_0..x_(#U-1)}
	  U = apply(U, i -> i + sum(V - set J)); --make sure V and J jive so that this makes sense, also in later version multiply the sum by a random in k
      	  --note that right now we can get stuck in an infinite loop as we aren't multiplying by a random
	  g := map(R,R,reverse(U|V));
	  h = g*f;
	  done = lastCheck(gb h I, #U);
	  if done then return((gens gb h I,h));
	  (U,V) = varPrep G;
      	  );
     );

-- end skip






noetherDecider = method();
noetherDecider(Ideal,GroebnerBasis,List,List) := Sequence => (I,G,U,V) -> (
     if dim I == #U then noetherPrime(I,G,U,V) else noetherNotPrime(I,G,U,V)
     );

noetherNormalization = method();
noetherNormalization(Ideal) := Sequence => I -> (
     G := gb I;
     (U,V) :=varPrep G;
     noetherDecider(I,G,U,V)
     );     



--========================================================
--Examples:
clearAll
R = QQ[x_4,x_3,x_2,x_1, MonomialOrder => Lex]; --the same ordering as in the paper
XP = permutations gens R
I =ideal(x_3^3+x_2^2+1)
(U,V) = varPrep(gb I)
for i from 1 to #XP-1 do (
     m = map(R,R,XP_i);
     (U,V) = varPrep(gb m I);
     if #U == dim I then break);




p = ideal(x_2^2+x_1*x_2+1, x_1*x_2*x_3*x_4+1);
noetherNormalization(p)
benchmark "noetherNormalization(p)"
R = QQ[x_2,x_1]
p = ideal(x_2*x_1+1)
noetherNormalization(p)



-- TO DO:
-- clear up output
-- get randomness
-- implement for nonprime ideals

-- Ok as far as the not prime case is concerned, let's write it as follows:
-- 
-- We'll do it with 3 routines.
-- 
-- noetherDecider
--         Will output T, and decided with algoritm to use.
--
-- noetherPrime
--        Will utilize the T being outputted
--
-- noetherNotPrime
--     	  Will also use T being outputted.



-- Older NN

noetherNormalization = method();
noetherNormalization(Ideal) := Sequence => I -> (
     R := ring I;    
     G := gb I; -- so far so good
     done := false;
     while done == false do ( --use of #U=dimI here and below must be replaced if I is not prime
	  (U,V) := varPrep G;
	  X := U | V;
	  f := map(R,R,reverse X);
	  G = gb f(I); --we should not need to do this gb computation
	  J := integralSet(G);
	  V = apply(V, i -> f(i)); --there might be a faster way to do this, perhaps V={x_(#U)..x_(#U+#V-1)}
	  U = apply(U, i -> f(i)); -- might be faster to do U = {x_0..x_(#U-1)}
	  U = apply(U, i -> i + sum(V - set J)); --make sure V and J jive so that this makes sense, also in later version multiply the sum by a random in k
      	  --note that right now we can get stuck in an infinite loop as we aren't multiplying by a random
	  g := map(R,R,reverse(U|V));
	  h = g*f;
	  done = lastCheck(gb h I, #U);
	  if done then return((gens gb h I,h));      	  
      	  );
     );








--=========================================================================--

beginDocumentation() -- the start of the documentation

-----------------------------------------------------------------------------

--docs

--=========================================================================--



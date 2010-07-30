-------------------
-- Package Header
-------------------
-- Released under the GNU GPL v2 or later
-- As this package is intended to be used with Macaulay 2, see the file 
-- COPYING in the root directory of the Macaulay 2 installation.

needsPackage "EdgeIdeals";
newPackage (
    "Nauty",
    Version => "0.5.2",
    Date => "30. July 2010",
    Authors => {{Name => "David W. Cook II",
                 Email => "dcook@ms.uky.edu",
                 HomePage => "http://www.ms.uky.edu/~dcook"}},
    Headline => "Interface to nauty",
    Configuration => {"path" => ""},
    CacheExampleOutput => true,
    AuxiliaryFiles => true,
    DebuggingMode => false
);
needsPackage "EdgeIdeals";

-------------------
-- Configuration
-------------------

-- Check the ~/.Macaulay2/init-Nauty.m2 file for the absolute path.
path'nauty = (options Nauty).Configuration#"path";
-- If it's not there, then use the M2-Programs directory.
if path'nauty == "" then path'nauty = prefixDirectory | currentLayout#"programs";

-------------------
-- Exports
-------------------

export {
    -- Methods
    addEdges,
    areIsomorphic,
    buildGraphFilter,
    countGraphs,
    filterGraphs,
    generateBipartiteGraphs,
    generateGraphs,
    generateRandomGraphs,
    generateRandomRegularGraphs,
    graph6ToSparse6,
    graphComplement,
    graphToString,
    isPlanar,
    neighborhoodComplements,
    newEdges,
    relabelBipartite,
    relabelGraph,
    removeEdges,
    removeIsomorphs,
    sparse6ToGraph6,
    stringToEdgeIdeal,
    stringToGraph,
    -- Options
    Class2Degree2,
    Class2DistinctNeighborhoods,
    Class2MaxCommonNeighbors,
    Convert,
    MaxDegree,
    MinDegree,
    NoNew3Cycles,
    NoNew4Cycles,
    NoNew5Cycles,
    NoNewOddCycles,
    NoNewSmallCycles,
    Only4CycleFree,
    OnlyBiconnected,
    OnlyBipartite,
    OnlyConnected,
    OnlyIfSmaller,
    OnlyTriangleFree
};

-------------------
-- Exported Code
-------------------

-- Finds all graphs of G with an extra edge added.
addEdges = method(Options => {MaxDegree => 0, NoNewOddCycles => false, NoNew3Cycles => false, NoNew4Cycles => false, NoNew5Cycles => false, NoNewSmallCycles => 0});
addEdges String := List => opts -> S -> (
    cmdStr := "addedgeg -q" |
        (if instance(opts.MaxDegree, ZZ) and opts.MaxDegree > 0 then " -D" | toString(opts.MaxDegree) else "") |
        (if instance(opts.NoNewOddCycles, Boolean) and opts.NoNewOddCycles then " -b" else "") |
        (if instance(opts.NoNew3Cycles, Boolean) and opts.NoNew3Cycles then " -t" else "") |
        (if instance(opts.NoNew4Cycles, Boolean) and opts.NoNew4Cycles then " -f" else "") |
        (if instance(opts.NoNew5Cycles, Boolean) and opts.NoNew5Cycles then " -F" else "") |
        (if instance(opts.NoNewSmallCycles, ZZ) and opts.NoNewSmallCycles > 0 then " -z" | toString(opts.NoNewSmallCycles) else "");
    callNauty(cmdStr, {S})
);
addEdges Graph := List => opts -> G -> (
    r := addEdges(graphToString G, opts);
    apply(r, l -> stringToGraph(l, ring G))
);

-- Determines if two graphs are isomorphic. 
areIsomorphic = method();
areIsomorphic (String, String) := Boolean => (G, H) -> (
    r := callNauty("shortg -q", {G, H});
    #r == 1
);
areIsomorphic (Graph, Graph) := Boolean => (G, H) -> areIsomorphic(graphToString G, graphToString H);

-- Build's a filter string for nauty's pickg/countg.
buildGraphFilter = method();
buildGraphFilter HashTable := String => h -> (
    validType := (str, type) -> h#?str and instance(h#str, type);
    propStart := (str) -> if validType(str, Boolean) and h#str then "-~" else "-";
    propBuildBoolean := (str, flag) -> if validType(str, Boolean) then ((if h#str then "-" else "-~") | flag) else "";
    propBuildZZSeq := (str, flag) -> (
        if validType(str, ZZ) and h#str >= 0 then (
            propStart("Negate" | str) | flag | toString h#str
        ) else if validType(str, Sequence) and #h#str == 2 then (
            if instance(h#str#0, Nothing) and instance(h#str#1, ZZ) and h#str#1 >= 0 then (
                propStart("Negate" | str) | flag | ":" | toString h#str#1
            ) else if instance(h#str#0, ZZ) and instance(h#str#1, Nothing) and h#str#0 >= 0 then (
                propStart("Negate" | str) | flag | toString h#str#0 | ":"
            ) else if instance(h#str#0, ZZ) and instance(h#str#1, ZZ) and h#str#0 >=0 and h#str#1 >= h#str#0 then (
                propStart("Negate" | str) | flag | toString h#str#0 | ":" | toString h#str#1
            ) else ""
        ) else ""
    );

    filter := {propBuildZZSeq("NumVertices", "n"),         propBuildZZSeq("NumEdges", "e"),
               propBuildZZSeq("MinDegree", "d"),           propBuildZZSeq("MaxDegree", "D"),
               propBuildBoolean("Regular", "r"),           propBuildBoolean("Bipartite", "b"),
               propBuildZZSeq("Radius", "z"),              propBuildZZSeq("Diameter", "Z"),
               propBuildZZSeq("Girth", "g"),               propBuildZZSeq("NumCycles", "Y"),
               propBuildZZSeq("NumTriangles", "T"),        propBuildBoolean("Eulerian", "E"),
               propBuildZZSeq("GroupSize", "a"),           propBuildZZSeq("Orbits", "o"),
               propBuildZZSeq("FixedPoints", "F"),         propBuildBoolean("VertexTransitive", "t"),
               propBuildZZSeq("Connectivity", "c"),
               propBuildZZSeq("MinCommonNbrsAdj", "i"),    propBuildZZSeq("MaxCommonNbrsAdj", "I"),
               propBuildZZSeq("MinCommonNbrsNonAdj", "j"), propBuildZZSeq("MaxCommonNbrsNonAdj", "J")
              };

    concatenate apply(filter, f -> if #f > 0 then (f | " ") else "")
);

-- Count the graphs with certian properties.
countGraphs = method();
countGraphs (List, String) := List => (L, filter) -> (
    if #L == 0 or #filter == 0 then return #L;
    r := callNauty("countg -q " | filter, apply(L, graphToString));
    if not instance(r, List) or #r == 0 then return;
    p := regex("g", first r);
    if not instance(p, Nothing) then value substring((0, first first regex("g", first r)), first r) else error("countGraphs: Invalid input; external call to Nauty failed.")
);
countGraphs (List, HashTable) := List => (L, fh) -> countGraphs(L, buildGraphFilter fh);

-- Filter a list of graphs for certain properties.
filterGraphs = method();
filterGraphs (List, String) := List => (L, filter) -> (
    if #L == 0 or #filter == 0 then return L;
    r := callNauty("pickg -qV " | filter | " 2>&1 1>/dev/null", apply(L, graphToString));
    -- In Nauty 2.4r1, the index is the first number.
    for l in r list ( s := select("[[:digit:]]+", l); if #s == 0 then continue else L_(-1 + value first s) )
);
filterGraphs (List, HashTable) := List => (L, fh) -> filterGraphs(L, buildGraphFilter fh);

-- Generates all bipartite graphs of a given type.
generateBipartiteGraphs = method(Options => {OnlyConnected => false, Class2DistinctNeighborhoods => false, Class2Degree2 => false, Class2MaxCommonNeighbors => 0, MaxDegree => 0, MinDegree => 0, Convert => true});
generateBipartiteGraphs (ZZ, ZZ, ZZ, PolynomialRing) := List => opts -> (m, le, ue, R) -> (
    if m >= #gens R then error("generateBipartiteGraphs: The first class has too many vertices.");
    if m < 1 then error("generateBipartiteGraphs: The first class has too few vertices.");
    n := #gens R - m;
    if (m<0) or (n<0) or (le > ue) or (le > m*n) or (ue < 0) then return;

    cmdStr := "genbg -q" | 
        (if instance(opts.OnlyConnected, Boolean) and opts.OnlyConnected then " -c" else "") |
        (if instance(opts.Class2DistinctNeighborhoods, Boolean) and opts.Class2DistinctNeighborhoods then " -z" else "") |
        (if instance(opts.Class2Degree2, Boolean) and opts.Class2Degree2 then " -F" else "") |
        (if instance(opts.Class2MaxCommonNeighbors, ZZ) and opts.Class2MaxCommonNeighbors > 0 then " -Z" | toString(opts.Class2MaxCommonNeighbors) else "") |
        (if instance(opts.MinDegree, ZZ) and opts.MinDegree > 0 then " -d" | toString(opts.MinDegree) else "") |
        (if instance(opts.MaxDegree, ZZ) and opts.MaxDegree > 0 then " -D" | toString(opts.MaxDegree) else "") |
        (" " | toString(m) | " " | toString(n) | " " | toString(le) | ":" | toString(ue) | " 2>&1");

    r := callNauty(cmdStr, {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);
generateBipartiteGraphs (ZZ, ZZ, PolynomialRing) := List => opts -> (m, e, R) -> generateBipartiteGraphs(m, e, e, R, opts);
generateBipartiteGraphs (ZZ, PolynomialRing) := List => opts -> (m, R) -> generateBipartiteGraphs(m, 0, m * (#gens R - m), R, opts);
generateBipartiteGraphs (PolynomialRing) := List => opts -> (R) -> (
    r := unique flatten apply(toList (1..(#gens R - 1)), i -> generateBipartiteGraphs(i, R, opts ++ new OptionTable from {Convert => false}));
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);

-- Generates all graphs of a given type.
generateGraphs = method(Options => {OnlyConnected => false, OnlyBiconnected => false, OnlyTriangleFree => false, Only4CycleFree => false, OnlyBipartite => false, MinDegree => 0, MaxDegree => 0, Convert => true});
generateGraphs (ZZ, ZZ, PolynomialRing) := List => opts -> (le, ue, R) -> (
    n := #gens R;
    if (n < 0) or (le > ue) or (le > binomial(n,2)) or (ue < 0) then return;
    le = max(le, 0);

    cmdStr := "geng -q" |
        (if instance(opts.OnlyConnected, Boolean) and opts.OnlyConnected then " -c" else "") |
        (if instance(opts.OnlyBiconnected, Boolean) and opts.OnlyBiconnected then " -C" else "") |
        (if instance(opts.OnlyTriangleFree, Boolean) and opts.OnlyTriangleFree then " -t" else "") |
        (if instance(opts.Only4CycleFree, Boolean) and opts.Only4CycleFree then " -f" else "") |
        (if instance(opts.OnlyBipartite, Boolean) and opts.OnlyBipartite then " -b" else "") |
        (if instance(opts.MinDegree, ZZ) and opts.MinDegree > 0 then " -d" | toString(opts.MinDegree) else "") |
        (if instance(opts.MaxDegree, ZZ) and opts.MaxDegree > 0 then " -D" | toString(opts.MaxDegree) else "") |
        (" " | toString(n) | " " | toString(le) | ":" | toString(ue) | " 2>&1");

    r := callNauty(cmdStr, {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);
generateGraphs (ZZ, PolynomialRing) := List => opts -> (e, R) -> generateGraphs(e, e, R, opts);
generateGraphs (PolynomialRing) := List => opts -> (R) -> generateGraphs(0, binomial(#gens R, 2), R, opts);

-- Generate random graphs in the Ring with given properties.
generateRandomGraphs = method(Options => {Convert => true});
generateRandomGraphs (ZZ, ZZ, PolynomialRing) := List => opts -> (num, p, R) -> (
    if num < 1 then return {};
    if p < 1 then error("generateRandomGraphs: Probability must be positive.");
    r := callNauty("genrang -qg -P" | toString(p) | " "  | toString(#gens R) | " " | toString(num), {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);
generateRandomGraphs (ZZ, QQ, PolynomialRing) := List => opts -> (num, p, R) -> (
    if num < 1 then return {};
    if p <= 0 or p > 1 then error("generateRandomGraphs: Probability must be between 0 and 1.");
    r := callNauty("genrang -qg -P" | toString(p) | " "  | toString(#gens R) | " " | toString(num), {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) and instance(r, List) then apply(r, l -> stringToGraph(l, R)) else r
);
generateRandomGraphs (ZZ, PolynomialRing) := List => opts -> (num, R) -> (
    if num < 1 then return {};
    r := callNauty("genrang -qg " | toString(#gens R) | " " | toString(num), {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);

-- Generate random graphs in the Ring with given properties.
generateRandomRegularGraphs = method(Options => {Convert => true});
generateRandomRegularGraphs (ZZ, ZZ, PolynomialRing) := List => opts -> (num, reg, R) -> (
    if num < 1 then return {};
    if reg < 1 or reg >= #gens R then error("generateRandomRegularGraphs: Regularity must be positive but less than the number of vertices.");
    r := callNauty("genrang -q -r" | toString(reg) | " " | toString(#gens R) | " " | toString(num) | " 2>&1", {});
    if (not instance(opts.Convert, Boolean) or opts.Convert) then apply(r, l -> stringToGraph(l, R)) else r
);

-- Converts a Graph6 string to a Sparse6 string.
graph6ToSparse6 = method();
graph6ToSparse6 String := String => g6 -> (
    r := callNauty("copyg -qs", {g6});
    if #r != 0 then first r else error("graph6ToSparse6: Invalid String format.")
);

-- Complements a graph.
graphComplement = method(Options => {OnlyIfSmaller => false});
graphComplement String := String => opts -> S -> (
    cmdStr := "complg -q" | (if instance(opts.OnlyIfSmaller, Boolean) and opts.OnlyIfSmaller then " -r" else "");
    r := callNauty(cmdStr, {S});
    if #r != 0 then first r else error("graphComplement: Invalid String format.")
);
graphComplement Graph := Graph => opts -> G -> (
    r := graphComplement(graphToString G, opts);
    if not instance(r, Nothing) then stringToGraph(r, ring G)
);

-- Converts a graph to a string in Graph6 format.
graphToString = method();
graphToString (List, ZZ) := String => (E, n) -> (
    if n > 68719476735 then error("graphToString: Too many vertices.");
    N := take(reverse apply(6, i -> (n // 2^(6*i)) % 2^6), if n < 63 then -1 else if n < 258047 then -3 else -6);

    B := new MutableList from toList(6*ceiling(binomial(n,2)/6):0);
    for e in E do B#(binomial(last e, 2) + first e) = 1;
    ascii apply(N | apply(pack(6, toList B), b -> fold((i,j) -> i*2+j, b)), l -> l + 63)
);
graphToString MonomialIdeal := String => I -> graphToString(apply(first entries generators I, indices), #gens ring I);
graphToString Ideal := String => I -> graphToString monomialIdeal I;
graphToString Graph := String => G -> graphToString(apply(edges G, e -> apply(e, index)), #vertices G);
graphToString String := String => S -> S;

-- Tests planarity of a graph
isPlanar = method();
isPlanar String := Boolean => G -> (
    r := callNauty("planarg -q", {G});
    #r != 0
);
isPlanar Graph := Boolean => G -> isPlanar(graphToString G);

-- For each vertex, switch the edges between its neighborhood and it's neighborhood's complement.
neighborhoodComplements = method();
neighborhoodComplements String := List => S -> callNauty("NRswitchg -q", {S});
neighborhoodComplements Graph := List => G -> (
    r := neighborhoodComplements graphToString G;
    apply(r, l -> stringToGraph(l, ring G))
);
    
-- For each disjoint pair of edges (a,b), (c,d), replace the edges with 
-- (a,e), (e,b), (c,f), (f,d), and add the edge (e,f), where {e,f} are
-- new vertices.
newEdges = method();
newEdges String := List => S -> callNauty("newedgeg -q", {S});
newEdges (Graph, PolynomialRing) := List => (G, S) -> (
    if #vertices G + 2 != #gens S then error("newEdges: The ring must have exactly two more variables than the graph has vertices.");
    r := newEdges graphToString G;
    apply(r, l -> stringToGraph(l, S))
);

-- Reorders a bipartite graph so all vertices of each color are continguous.
relabelBipartite = method();
relabelBipartite String := String => S -> (
    r := callNauty("biplabg -q", {S});
    if #r != 0 then first r else error("relabelBipartite: Invalid String format or input is not a bipartite graph.")
);
relabelBipartite Graph := Graph => G -> (
    r := relabelBipartite graphToString G;
    stringToGraph(r, ring G)
);

-- Relabels a graph using a canonical labeling.
relabelGraph = method();
relabelGraph (String, ZZ, ZZ) := String => (S, i, a) -> (
    if i > 15 or i < 1 then error("relabelGraph: The invariant selected is invalid.");
    if a < 0 then error("relabelGraph: The invariant argument must be nonnegative.");
    r := callNauty("labelg -qg -i" | toString i | " -K" | toString a, {S});
    if #r != 0 then first r else error("relabelGraph: Invalid String format.")
);
relabelGraph (String, ZZ) := String => (S, i) -> relabelGraph(S, i, 3);
relabelGraph (Graph, ZZ, ZZ) := Graph => (G, i, a) -> (
    r := relabelGraph(graphToString G, i, a);
    stringToGraph(r, ring G)
);
relabelGraph (Graph, ZZ) := Graph => (G, i) -> relabelGraph(G, i, 3);
        
-- Finds all graphs of G with one edge removed.
removeEdges = method(Options => {MinDegree => 0});
removeEdges String := List => opts -> S -> (
    cmdStr := "deledgeg -q" | (if instance(opts.MinDegree, ZZ) and opts.MinDegree > 0 then " -d" | toString(opts.MinDegree) else "");
    callNauty(cmdStr, {S})
);
removeEdges Graph := List => opts -> G -> (
    r := removeEdges(graphToString G, opts);
    apply(r, l -> stringToGraph(l, ring G))
);

-- Removes all isomorphs from a list of graphs. 
removeIsomorphs = method();
removeIsomorphs List := List => L -> (
    if #L == 0 then return {};
    r := callNauty("shortg -qv 2>&1 1>/dev/null", apply(L, graphToString));
    -- In Nauty 2.4r1, the index is the second number.
    for l in r list ( s := select("[[:digit:]]+", l); if #s < 2 then continue else L_(-1 + value (s_1)) )
);

-- Converts a Sparse6 string to a Graph6 string.
sparse6ToGraph6 = method();
sparse6ToGraph6 String := String => (s6) -> (
    r := callNauty("copyg -qg", {s6});
    if #r != 0 then first r else error("sparse6ToGraph6: Invalid String format.")
);

-- Converts a graph given by a string in either Sparse6 or Graph6 format to an edge ideal in the given ring.
stringToEdgeIdeal = method();
stringToEdgeIdeal (String, PolynomialRing) := MonomialIdeal => (str, R) -> (
    -- basic parse
    if #str == 0 then return;
    sparse := str_0 == ":";
    A := apply(ascii str, l -> l - 63);
    if sparse then A = drop(A, 1);
    if min A < 0 or max A > 63 then error("stringToEdgeIdeal: Not a sparse6/graph6 string.");

    -- get number of vertices
    p := 0;
    n := if A_0 < 63 then (
             p = 1;
             A_0
         ) else if A_1 < 63 then ( 
             if #A < 4 then error("stringToEdgeIdeal: Not a sparse6/graph6 string.");
             p = 4;
             fold((i,j) -> i*2^6+j, take(A, {1,3}))
         ) else (
             if #A < 8 then error("stringToEdgeIdeal: Not a sparse6/graph6 string.");
             p = 8;
             fold((i,j) -> i*2^6+j, take(A, {2,7}))
         );
    if #gens R != n then error("stringToEdgeIdeal: Wrong number of variables in the ring.");

    bits := flatten apply(drop(A, p), n -> ( n = n*2; reverse for i from 1 to 6 list (n=n//2)%2 ));
    c := 0;

    E := if sparse then (
        -- sparse6 format
        k := ceiling(log(n) / log(2));
        v := 0;
        xi := 0;
        while c + k < #bits list (
            if bits_c == 1 then v = v + 1;
            xi = fold((i,j) -> 2*i+j, take(bits, {c+1,c+k})); 
            c = c + k + 1;
            if xi > v then ( v = xi; continue ) else (R_xi*R_v)
        )
    ) else ( 
        -- graph6 format
        if #A != p + ceiling(n*(n-1)/12) then error("stringToEdgeIdeal: Not a graph6 string.");
        c = -1;
        flatten for i from 1 to n - 1 list for j from 0 to i - 1 list ( c = c + 1; if bits_c == 1 then (R_i*R_j) else continue)
    );
    monomialIdeal if #E == 0 then 0_R else E
);

-- Converts a graph given by a string in either Sparse6 or Graph6 format to a graph in the given ring.
stringToGraph = method();
stringToGraph (String, PolynomialRing) := Graph => (str, R) -> (
    graph stringToEdgeIdeal(str, R)
);

-------------------
-- Local-Only Code
-------------------

-- Sends a command and gets the results into a list of lines.
callNauty = method();
callNauty (String, List) := List => (cmdStr, dataList) -> (
    try (
        f := openInOut ("!" | path'nauty | cmdStr);
        apply(dataList, d -> f << d << endl);
        f << closeOut;
        r := lines get f;
        if instance(r, Nothing) then r = {};
    ) then r else error("callNauty: External call to Nauty has failed; ensure that Nauty is on the path and the input is valid.")
);

-------------------
-- Documentation
-------------------
beginDocumentation()

doc ///
    Key
        Nauty
    Headline
        Interface to nauty
    Description
        Text
            This package interfaces many of the functions provided in the software {\tt nauty}
            by Brendan D. McKay, available at @HREF"http://cs.anu.edu.au/~bdm/nauty/"@.  
            The {\tt nauty} package provides very efficient methods for determining whether
            given graphs are isomorphic, generating all graphs with particular properties,
            generating random graphs, and more.
            
            Most methods can handle graphs in either the Macaulay2 Graph type as provided by
            the {\tt EdgeIdeals} package or as Graph6 and Sparse6 Strings as used by {\tt nauty}.
            The purpose of this is that graphs stored as strings are greatly more efficient than
            graphs stored as Graphs.  It is recommended to work with Strings while using {\tt nauty}
            provided methods and then converting to Graphs for further work (e.g., computing the
            chromatic number).

            The theoretical underpinnings of {\tt nauty} are in the paper:
            B. D. McKay, {\em Practical graph isomorphism,} Congr. Numer. {\bf 30} (1981), 45--87.
    Caveat
        This package was designed for use with {\tt nauty} version 2.4r1.  It may or may not work
        with future versions.

        The {\tt nauty} software must be installed locally and the path should be known to {\tt Macaulay2},
        either by passing it as an argument when loading (e.g., {\tt loadPackage("Nauty",
        Configuration=>\{"path"=>"/usr/local/bin/"\})}) or by editing the configuration file
        {\tt .Macaulay2/init-Nauty.m2} to automatically include the path.
///

doc ///
    Key
        addEdges
        (addEdges, String)
        (addEdges, Graph)
        [addEdges, MaxDegree]
        [addEdges, NoNew3Cycles]
        [addEdges, NoNew4Cycles]
        [addEdges, NoNew5Cycles]
        [addEdges, NoNewOddCycles]
        [addEdges, NoNewSmallCycles]
    Headline
        creates a list of graphs obtained by adding one new edge to the given graph in all possible ways
    Usage
        Lg = addEdges G
        Ls = addEdges S
    Inputs
        S:String
            which describes a graph in Graph6 or Sparse6 format
        G:Graph
            which is built by the EdgeIdeals package
    Outputs
        Lg:List
            the list of Graphs obtained from {\tt G}
        Ls:List
            the list of Strings (in Graph6 format) obtained from {\tt S}
    Description
        Text
            Simply creates a list, in the same format as the input, of all possible graphs obtained by
            adding one new edge to the input graph.  
        Example
            R = QQ[a..e];
            addEdges cycle R
    SeeAlso
        removeEdges
///

doc ///
    Key
        areIsomorphic
        (areIsomorphic, String, String)
        (areIsomorphic, Graph, Graph)
    Headline
        determines whether two graphs are isomorphic
    Usage
        b = areIsomorphic(G, H)
        b = areIsomorphic(S, T)
    Inputs
        G:Graph
        H:Graph
        S:String
        T:String
    Outputs
        b:Boolean
            whether the two graphs are isomorphic
    Description
        Text
            A very efficient method for determing whether two graphs (of the same format) are isomorphic.
        Example
            R = QQ[a..e];
            areIsomorphic(cycle R, graph {a*c, c*e, e*b, b*d, d*a})
            areIsomorphic("Dhc", "D~{") -- "Dhc" = cycle R, "D~{" = completeGraph R
    SeeAlso
        removeIsomorphs
///

doc ///
    Key
        buildGraphFilter
        (buildGraphFilter, HashTable)
    Headline
        creates the appropriate filter string for use with @TO filterGraphs@ and @TO countGraphs@
    Usage
        s = buildGraphFilter h
    Inputs
        h:HashTable
            which describes the properties desired in filtering
    Outputs
        s:String
            which can be used with @TO filterGraphs@ and @TO countGraphs@
    Description
        Text
            The @TO filterGraphs@ and @TO countGraphs@ methods both can use a tremendous number of constraints
            which are described be a rather tersely encoded string.  This method builds that string given information
            in the hash table {\tt h}.  Any keys which do not exist are simply ignored and any values which are not valid
            (e.g., exactly {\tt -3} vertices) are ignored.
            
            The values can either be boolean or numerical.   Boolean values are treated exactly
            as expected.  Numerical values are more complicated; we use an example to illustrate, but this works for
            all numerically valued keys.
 
            The key {\tt "NumEdges"} restricts to a specific number of edges in the graph.  If the value is
            the integer {\tt n}, then only graphs with {\em exactly} {\tt n} edges are returned.
        Example
            R = QQ[a..f];
            L = {graph {a*b}, graph {a*b, b*c}, graph {a*b, b*c, c*d}, graph {a*b, b*c, c*d, d*e}};
            s = buildGraphFilter hashTable {"NumEdges" => 3}
            filterGraphs(L, s)
        Text
            If the value is the sequence {\tt (m,n)}, then all graphs with at least {\tt m} and at most {\tt n} edges are returned.
        Example
            s = buildGraphFilter hashTable {"NumEdges" => (2,3)}
            filterGraphs(L, s)
        Text
            If the value is the sequence {\tt (,n)}, then all graphs with at most {\tt n} edges are returned.
        Example
            s = buildGraphFilter hashTable {"NumEdges" => (,3)}
            filterGraphs(L, s)
        Text
            If the value is the sequence {\tt (m,)}, then all graphs with at least {\tt m} edges are returned.
        Example
            s = buildGraphFilter hashTable {"NumEdges" => (2,)}
            filterGraphs(L, s)
        Text
            Moreover, the associated key {\tt "NegateNumEdges"}, if true, causes the {\em opposite} to occur.
        Example
            s = buildGraphFilter hashTable {"NumEdges" => (2,), "NegateNumEdges" => true}
            filterGraphs(L, s)
        Text
            The following are the boolean options: "Regular", "Bipartite", "Eulerian", "VertexTransitive".

            The following are the numerical options (recall all have the associate "Negate" option): "NumVertices", "NumEdges",
            "MinDegree", "MaxDegree", "Radius", "Diameter", "Girth", "NumCycles", "NumTriangles", "GroupSize", "Orbits",
            "FixedPoints", "Connectivity", "MinCommonNbrsAdj", "MaxCommonNbrsAdj", "MinCommonNbrsNonAdj", "MaxCommonNbrsNonAdj".
    Caveat
            {\bf "Connectivity"} only works for the values {\tt 0, 1, 2} and is strict, that is, {\tt \{"Connectivity" => 1\}}
            yields only those graphs with exactly 1-connectivity.  In order to filter for connected graphs, one must use
            {\tt \{"Connectivity" => 0, "NegateConnectivity" => true\}}.
    SeeAlso
        countGraphs
        filterGraphs
///

doc ///
    Key
        countGraphs
        (countGraphs, List, String)
        (countGraphs, List, HashTable)
    Headline
        counts the number of graphs in the list with given properties
    Usage
        n = countGraphs(L, s)
        n = countGraphs(L, h)
    Inputs
        L:List
            contains graphs (mixed formats are allowed) which will be counted
        s:String
            a filter, as generated by @TO buildGraphFilter@
        h:HashTable
            a filter, as used by @TO buildGraphFilter@
    Outputs
        n:ZZ
            the number of graphs in {\tt L} satisfying the filter
    Description
        Text
            Counts the number of graphs in a list which satisfy certain restraints as given in
            the filter (see @TO buildGraphFilter@).  Notice that the input list can be graphs in
            both Graph format and String format.
        Example
            R = QQ[a..e];
            L = generateGraphs(R, Convert => false);
            countGraphs(L, hashTable {"Connectivity" => 0, "NegateConnectivity" => true}) -- the number of connected graphs on five vertices
    SeeAlso
        buildGraphFilter
        filterGraphs
///

doc ///
    Key
        filterGraphs
        (filterGraphs, List, String)
        (filterGraphs, List, HashTable)
    Headline
        filters graphs in a list for given properties
    Usage
        F = filterGraphs(L, s)
        F = filterGraphs(L, h)
    Inputs
        L:List
            contains graphs (mixed formats are allowed) which will be filtered
        s:String
            a filter, as generated by @TO buildGraphFilter@
        h:HashTable
            a filter, as used by @TO buildGraphFilter@
    Outputs
        F:List
            the graphs in {\tt L} satisfying the filter
    Description
        Text
            Filters the graphs in a list which satisfy certain restraints as given in
            the filter (see @TO buildGraphFilter@).  Notice that the input list can be graphs in
            both Graph format and String format.
        Example
            R = QQ[a..e];
            L = generateGraphs(R, Convert => false);
            filterGraphs(L, hashTable {"Connectivity" => 0, "NegateConnectivity" => true}) -- the connected graphs on five vertices
    SeeAlso
        buildGraphFilter
        countGraphs
///

doc ///
    Key
        generateBipartiteGraphs
        (generateBipartiteGraphs, PolynomialRing)
        (generateBipartiteGraphs, ZZ, PolynomialRing)
        (generateBipartiteGraphs, ZZ, ZZ, PolynomialRing)
        (generateBipartiteGraphs, ZZ, ZZ, ZZ, PolynomialRing)
        [generateBipartiteGraphs, Class2Degree2]
        [generateBipartiteGraphs, Class2DistinctNeighborhoods]
        [generateBipartiteGraphs, Class2MaxCommonNeighbors]
        [generateBipartiteGraphs, Convert]
        [generateBipartiteGraphs, MaxDegree]
        [generateBipartiteGraphs, MinDegree]
        [generateBipartiteGraphs, OnlyConnected]
    Headline
        generates the bipartite graphs with a given bipartition
    Usage
        G = generateBipartiteGraphs R
        G = generateBipartiteGraphs(m, R)
        G = generateBipartiteGraphs(m, e, R)
        G = generateBipartiteGraphs(m, le, ue, R)
    Inputs
        R:PolynomialRing
            the ring in which the graphs will be created
        m:ZZ
            the number of vertices in one part of the bipartition
        e:ZZ
            the number of edges in the graphs
        le:ZZ
            a lower bound on the number of edges in the graphs
        ue:ZZ
            an upper bound on the number of edges in the graphs
    Outputs
        G:List
            the bipartite graphs in {\tt R} satisfying the input conditions
    Description
        Text
            This method generates all bipartite graphs in the polynomial ring {\tt R}
            with a given bipartition.  The size of the bipartition is specified
            by giving the size of one part; the other part is determined
            automatically from the number of generators of {\tt R}.

            In the options, Class2 refers to the second part of the bipartition.
        Example
            R = QQ[a..e];
            generateBipartiteGraphs(2, R)
    SeeAlso
        generateGraphs
///

doc /// 
    Key
        generateGraphs
        (generateGraphs, ZZ, ZZ, PolynomialRing)
        (generateGraphs, ZZ, PolynomialRing)
        (generateGraphs, PolynomialRing)
        [generateGraphs, Convert]
        [generateGraphs, MaxDegree]
        [generateGraphs, MinDegree]
        [generateGraphs, Only4CycleFree]
        [generateGraphs, OnlyBiconnected]
        [generateGraphs, OnlyBipartite]
        [generateGraphs, OnlyConnected]
        [generateGraphs, OnlyTriangleFree]
    Headline
        generates the graphs in a given polynomial ring
    Usage
        G = generateGraphs R
        G = generateGraphs(e, R)
        G = generateGraphs(le, ue, R)
    Inputs
        R:PolynomialRing
            the ring in which the graphs will be created
        e:ZZ
            the number of edges in the graphs
        le:ZZ
            a lower bound on the number of edges in the graphs
        ue:ZZ
            an upper bound on the number of edges in the graphs
    Outputs
        G:List
            the graphs in {\tt R} satisfying the input conditions
    Description
        Text
            This method generates all graphs in the polynomial ring {\tt R} 
            subject to the constraints on the number of edges.  It further
            uses several options to allow further constraining of the output.
        Example
            R = QQ[a..e];
            generateGraphs(4, 6, R, OnlyConnected => true)
    SeeAlso
        generateBipartiteGraphs
///

doc ///
    Key
        generateRandomGraphs
        (generateRandomGraphs, ZZ, PolynomialRing)
        (generateRandomGraphs, ZZ, QQ, PolynomialRing)
        (generateRandomGraphs, ZZ, ZZ, PolynomialRing)
        [generateRandomGraphs, Convert]
    Headline
        generates random graphs in a given polynomial ring
    Usage
        G = generateRandomGraphs(num, R)
        G = generateRandomGraphs(num, pq, R)
        G = generateRandomGraphs(num, pz, R)
    Inputs
        R:PolynomialRing
            the ring in which the graphs will be created
        num:ZZ
            the number of random graphs to generate
        pq:QQ
            the probability of a given edge being included (between 0 and 1)
        pz:ZZ
            the probability of a given edge being included (positive)
    Outputs
        G:List
            the randomly generated graphs in {\tt R}
    Description
        Text
            This method generates a specified number of random graphs in the
            polynomial ring {\tt R}.  Note that the graphs may be isomorphic.

            If the input {\tt pq} is included, then the edges are chosen to be
            included with probability {\tt pq}.  If the input {\tt pz} is included
            and is positive, then the edges are chose to be included with probability
            {\tt 1/pz}.
        Example
            R = QQ[a..e];
            generateRandomGraphs(5, R)
    SeeAlso
        generateRandomRegularGraphs
///

doc ///
    Key
        generateRandomRegularGraphs
        (generateRandomRegularGraphs, ZZ, ZZ, PolynomialRing)
        [generateRandomRegularGraphs, Convert]
    Headline
        generates random regular graphs in a given polynomial ring
    Usage
        G = generateRandomRegularGraphs(num, reg, R)
    Inputs
        R:PolynomialRing
            the ring in which the graphs will be created
        num:ZZ
            the number of random graphs to generate
        reg:ZZ
            the regularity of the generated graphs
    Outputs
        G:List
            the randomly generated regular graphs in {\tt R}
    Description
        Text
            This method generates a specified number of random graphs in
            the polynomial ring {\tt R} with a given regularity.
            Note that the graphs may be isomorphic.
        Example
            R = QQ[a..e];
            generateRandomRegularGraphs(3, 2, R)
    SeeAlso
        generateRandomGraphs
///

doc ///
    Key
        graph6ToSparse6
        (graph6ToSparse6, String)
    Headline
        converts a graph6 string to a sparse6 string
    Usage
        s6 = graph6ToSparse6 g6
    Inputs
        g6:String
            a string in Nauty's graph6 format
    Outputs
        s6:String
            a string in Nauty's sparse6 format
    Description
        Text
            This method converts a graph stored in Nauty's graph6 format
            to a graph stored in Nauty's sparse6 format.  For graphs with
            very few edges, the sparse6 format can use dramatically less
            space.  However, for graphs with many edges, the sparse6
            format can increase the storage requirements.
        Example
            graph6ToSparse6 "Dhc"
            graph6ToSparse6 "M????????????????"
    SeeAlso
        graphToString
        stringToEdgeIdeal
        stringToGraph
        sparse6ToGraph6
///

doc ///
    Key
        graphComplement
        (graphComplement, String)
        (graphComplement, Graph)
        [graphComplement, OnlyIfSmaller]
    Headline
        computes the complement of a graph
    Usage
        T = graphComplement S
        H = graphComplement G
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
    Outputs
        T:String
            the graph complement of {\tt S} stored in the same format at {\tt S}
        H:Graph
            the graph complement of {\tt G}
    Description
        Text
            This method computes the graph complement of the input graph
            and returns the result in the same format.  
            
            For graphs as defined in the @TO EdgeIdeals@ package, one can use the
            @TO complementGraph@ method to achieve the same effect; however,
            this method provides the option of not taking the complement if the
            complement has more edges than the graph itself.
        Example
            R = QQ[a..e];
            graphComplement cycle R
            graphComplement "Dhc"
    SeeAlso
        complementGraph
///

doc ///
    Key
        graphToString
        (graphToString, List, ZZ)
        (graphToString, MonomialIdeal)
        (graphToString, Ideal)
        (graphToString, Graph)
        (graphToString, String)
    Headline
        converts a graph to a string in the graph6 format
    Usage
        S = graphToString(E, n)
        S = graphToString I
        S = graphToString G
        S = graphToString T
    Inputs
        E:List
            a list of edge pairs
        n:ZZ
            the number of vertices in the graph
        I:Ideal
            the edge ideal of a graph
        G:Graph
        T:String
            a string containing a graph; the string automatically passes through untouched
    Outputs
        S:String
            the graph converted to a graph6 format string
    Description
        Text
            This method converts various ways of representing a graph into
            Nauty's graph6 string format.  Note that if the ideal (or monomial
            ideal) past to the method is not squarefree and monomial, then the
            method may have unknown and possibly undesired results.

            In this example, all graphs are the five cycle.
        Example
            graphToString({{0,1}, {1,2}, {2,3}, {3,4}, {0,4}}, 5)
            R = QQ[a..e];
            graphToString monomialIdeal (a*c, a*d, b*d, b*e, c*e)
            graphToString cycle R
            graphToString "Dhc"
    Caveat
        Notice that if using a list and number of vertices input to create
        the string, then the list must have vertices labeled {\tt 0} to
        {\tt n -1} and should be preferably in sorted order.
    SeeAlso
        graph6ToSparse6
        sparse6ToGraph6
        stringToGraph
///

doc ///
    Key
        isPlanar
        (isPlanar, Graph)
        (isPlanar, String)
    Headline
        determines if a given graph is planar
    Usage
        p = isPlanar G
        p = isPlanar S
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
    Outputs
        p:Boolean
            whether the given graph is planar
    Description
        Text
            A graph is planar if the graph can be embedded in the plane, i.e.,
            the vertices can be arranged such that no edges cross except at
            vertices.
        Example
            R = QQ[a..e];
            isPlanar cycle R
            isPlanar completeGraph R
        Text
            The method {\tt isPlanar} uses the program {\tt planarg}. The
            code was written by Paulette Lieby for the Magma project and
            used with permission in the Nauty package.
///

doc ///
    Key
        neighborhoodComplements
        (neighborhoodComplements, String)
        (neighborhoodComplements, Graph)
    Headline
        complements the neighborhood for each vertex, individually
    Usage
        L = neighborhoodComplements S
        L = neighborhoodComplements G
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
    Outputs
        L:List
            a list of graphs, in the same format as the input, modified as described below
    Description
        Text
            The method creates a list of graphs, one for each vertex of the
            original graph {\tt G}.  The graph associated to a vertex {\tt v}
            of {\tt G} has its neighborhood complemented.  

            The method does not remove isomorphs.
        Example
            R = QQ[a..e];
            neighborhoodComplements graph {a*b, a*c, b*c, c*d, d*e}
    SeeAlso
        graphComplement
        neighbors
///

doc ///
    Key
        newEdges
        (newEdges, String)
        (newEdges, Graph, PolynomialRing)
    Headline
        replaces disjoint pairs of edges by disjoint pairs of two-chains
    Usage
        L = newEdges S
        L = newEdges(G, R)
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
        R:PolynomialRing
            a ring with exactly two more variables than the ring of {\tt G}
    Outputs
        L:List
            a list of graphs, in the same format as the input, modified as described below
    Description
        Text
            The list of "new edge" graphs are formed as follows:
            Let {\tt ab} and {\tt cd} be disjoint edges of {\tt G}.  Then the
            associated "new edge" graph {\tt H} is {\tt G} with the edges
            {\tt ab} and {\tt cd} removed, the vertices {\tt e} and {\tt f} added,
            and the new edges {\tt ae, eb, cf,} and {\tt fd} added.
        Example
            R = QQ[a..d];
            G = graph {a*b, c*d};
            S = QQ[a..f];
            newEdges(G, S)
///

doc ///
    Key
        relabelBipartite
        (relabelBipartite, String)
        (relabelBipartite, Graph)
    Headline
        relabels a bipartite graph so all vertices of a given class are contiguous
    Usage
        T = relabelBipartite S
        H = relabelBipartite G
    Inputs
        S:String
            a bipartite graph encoded in either sparse6 or graph6 format
        G:Graph
            a bipartite graph
    Outputs
        T:String
            a graph isomorphic to {\tt S} encoded in either sparse6 or graph6 format
        H:Graph
            a graph isomorphic to {\tt G}
    Description
        Text
            A bipartite graph can be labeled so all vertices of a given
            class are contiguous.
        Example
            R = QQ[a..f];
            G = graph flatten apply({a,c,e}, v->v*{b,d,f})
            relabelBipartite G
    SeeAlso
        relabelGraph
///

doc ///
    Key
        relabelGraph
        (relabelGraph, String, ZZ, ZZ)
        (relabelGraph, String, ZZ)
        (relabelGraph, Graph, ZZ, ZZ)
        (relabelGraph, Graph, ZZ)
    Headline
        applies a canonical labeling to a graph
    Usage
        T = relabelGraph(S, i, a)
        T = relabelGraph(S, i)
        H = relabelGraph(G, i, a)
        H = relabelGraph(G, i)
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
        i:ZZ
            a choice of invariant to order by ({\tt 1 <= i <= 15})
        a:ZZ
            a non-negative argument passed to {\tt Nauty}, (default is three)
    Outputs
        T:String
            a graph isomorphic to {\tt S} encoded in either sparse6 or graph6 format
        H:Graph
            a graph isomorphic to {\tt G}
    Description
        Text
            This method applies one of fifteen canonical labelings to a graph.  See
            the {\tt Nauty} documentation for a more complete description of each
            and how the argument {\tt a} is used.

            {\tt i = 1}: twopaths

            {\tt i = 2}: adjtriang(K)

            {\tt i = 3}: triples

            {\tt i = 4}: quadruples

            {\tt i = 5}: celltrips

            {\tt i = 6}: cellquads

            {\tt i = 7}: cellquins

            {\tt i = 8}: distances(K)

            {\tt i = 9}: indsets(K)

            {\tt i = 10}: cliques(K)

            {\tt i = 11}: cellcliq(K)

            {\tt i = 12}: cellind(K)

            {\tt i = 13}: adjacencies

            {\tt i = 14}: cellfano

            {\tt i = 15}: cellfano2
        Example
            R = QQ[a..m];
            G = randomGraph(R, 20)
            unique apply(1..15, i -> relabelGraph(G, i))
        Text
            Note that on most small graphs, all fifteen orderings produce the same result.
    SeeAlso
        relabelBipartite
///

doc ///
    Key
        removeEdges
        (removeEdges, String)
        (removeEdges, Graph)
        [removeEdges, MinDegree]
    Headline
        creates a list of graphs obtained by removing one edge from the given graph in all possible ways
    Usage
        L = removeEdges S
        L = removeEdges G
    Inputs
        S:String
            a graph encoded in either sparse6 or graph6 format
        G:Graph
    Outputs
        L:List
            a list of all graphs obtained by removed one edge from the given graph in all possible ways; it contains graphs in the same format as the input
    Description
        Text
            This method creates a list of all possible graphs obtainable from
            the given graph by removing one edge.  Notice that isomorphic graphs
            are allowed within the list.
        Example
            R = QQ[a..e];
            removeEdges cycle R
            removeEdges graph {a*b, a*c, b*c, c*d, d*e}
    SeeAlso
        addEdges
///

doc ///
    Key
        removeIsomorphs
        (removeIsomorphs, List)
    Headline
        removes all isomorphs from a list of graphs
    Usage
        M = removeIsomorphs L
    Inputs
        L:List
            a list of graphs in either Graph or sparse6/graph6 String format
    Outputs
        M:List
            the sub-list of non-isomorphic graphs of the input list, retaining format
    Description
        Text
            This method returns the sublist of {\tt L} giving all 
            non-isomorphic graphs with selection based on which comes
            first in {\tt L}.  The format of the graph is retained.
        Example
            R = QQ[a..f];
            G = {"EhEG", cycle R, completeGraph R, graph {a*d, d*b, b*e, e*c, c*f, f*a}};
            removeIsomorphs G
    SeeAlso
        areIsomorphic
///

doc ///
    Key
        sparse6ToGraph6
        (sparse6ToGraph6, String)
    Headline
        converts a sparse6 string to a graph6 string
    Usage
        g6 = sparse6ToGraph6 s6
    Inputs
        s6:String
            a string in Nauty's sparse6 format
    Outputs
        g6:String
            a string in Nauty's graph6 format
    Description
        Text
            This method converts a graph stored in Nauty's sparse6 format
            to a graph stored in Nauty's graph6 format.  The graph6 format
            has the benefit of being a constant length dependent only
            on the number of vertices.
        Example
            sparse6ToGraph6 ":DaY_~"
            sparse6ToGraph6 ":M"
    SeeAlso
        graph6ToSparse6
        graphToString
        stringToEdgeIdeal
        stringToGraph
///

doc ///
    Key
        stringToEdgeIdeal
        (stringToEdgeIdeal, String, PolynomialRing)
    Headline
        converts a sparse6 or graph6 String to an edge ideal in the given polynomial ring
    Usage
        I = stringToEdgeIdeal(S, R)
    Inputs
        S:String
            a string in Nauty's sparse6 or graph6 format
        R:PolynomialRing
            a polynomial ring
    Outputs
        I:Ideal
            an ideal in the given polynomial ring
    Description
        Text
            This method converts a sparse6 or graph6 String {\tt S} to an edge
            ideal {\tt I} in the given polynomial ring {\tt R}.  That is, for
            each edge {\tt (a,b)} in the graph given by {\tt S}, the monomial
            {\tt a*b} is added as a generator to {\tt I}.  

            Note, this method requires that the number of variables of {\tt R}
            be the same as the number of vertices of {\tt S}.
        Example
            R = QQ[a..e];
            stringToEdgeIdeal("Dhc", R)
        Text
            This method is almost always faster than converting the String to
            a Graph and then to an edge ideal using the @TO edgeIdeal@ method.
    SeeAlso
        graphToString
        stringToGraph
///

doc ///
    Key
        stringToGraph
        (stringToGraph, String, PolynomialRing)
    Headline
        converts a sparse6 or graph6 String to a Graph in the given polynomial ring
    Usage
        G = stringToEdgeIdeal(S, R)
    Inputs
        S:String
            a string in Nauty's sparse6 or graph6 format
        R:PolynomialRing
            a polynomial ring
    Outputs
        G:Graph
            a graph in the given polynomial ring
    Description
        Text
            This method converts a sparse6 or graph6 String {\tt S} to a graph
            {\tt G} in the given polynomial ring {\tt R}.

            Note, this method requires that the number of variables of {\tt R}
            be the same as the number of vertices of {\tt S}.
        Example
            R = QQ[a..e];
            stringToGraph("Dhc", R)
    SeeAlso
        graphToString
        stringToEdgeIdeal
///

undocumented { 
    Class2Degree2,
    Class2DistinctNeighborhoods,
    Class2MaxCommonNeighbors,
    Convert,
    MaxDegree,
    MinDegree,
    NoNew3Cycles,
    NoNew4Cycles,
    NoNew5Cycles,
    NoNewOddCycles,
    NoNewSmallCycles,
    Only4CycleFree,
    OnlyBiconnected,
    OnlyBipartite,
    OnlyConnected,
    OnlyIfSmaller,
    OnlyTriangleFree
};

-------------------
-- Tests
-------------------

-- addEdges
TEST ///
    R = ZZ[a..f];
    assert(#addEdges cycle R == 9);
    assert(#addEdges completeGraph R == 0);
    -- "E???" is the empty graph
    assert(#addEdges "E???" == binomial(6, 2));
///

-- areIsomorphic
TEST ///
    R = ZZ[a..f];
    assert(areIsomorphic(cycle R, graph {a*c, c*e, e*b, b*d, d*f, f*a}));
    assert(not areIsomorphic(cycle R, completeGraph R));
    assert(areIsomorphic(complementGraph completeGraph R, graph monomialIdeal (0_R)));
///

-- buildGraphFilter
TEST ///
    assert(buildGraphFilter hashTable {"NumVertices" => 3} == "-n3 ");
    assert(buildGraphFilter hashTable {"NumVertices" => (3,4)} == "-n3:4 ");
    assert(buildGraphFilter hashTable {"NumVertices" => (3,)} == "-n3: ");
    assert(buildGraphFilter hashTable {"NumVertices" => (,4)} == "-n:4 ");
    assert(buildGraphFilter hashTable {"NumVertices" => 3, "NegateNumVertices" => true} == "-~n3 ");
    assert(buildGraphFilter hashTable {"Regular" => true} == "-r ");
    assert(buildGraphFilter hashTable {"Regular" => false} == "-~r ");
    assert(buildGraphFilter hashTable {} == "");
///

-- countGraphs
TEST ///
    R = ZZ[a..f];
    G = {cycle R, completeGraph R, graph monomialIdeal (0_R), graph {a*b, c*d, e*f}, graph {a*b, b*c, c*d, d*e}};
    -- Connected?
    assert(countGraphs(G, hashTable {"Connectivity" => 0, "NegateConnectivity" => true}) == 2);
    -- Bipartite?
    assert(countGraphs(G, hashTable {"Bipartite" => true}) == 4);
    -- At least 4 edges?
    assert(countGraphs(G, hashTable {"NumEdges" => (4,)}) == 3);
///

-- filterGraphs
TEST ///
    R = ZZ[a..f];
    G = {cycle R, completeGraph R, graph monomialIdeal (0_R), graph {a*b, c*d, e*f}, graph {a*b, b*c, c*d, d*e}};
    -- Connected?
    assert(filterGraphs(G, hashTable {"Connectivity" => 0, "NegateConnectivity" => true}) == G_{0, 1});
    -- Bipartite?
    assert(filterGraphs(G, hashTable {"Bipartite" => true}) == G_{0, 2, 3, 4});
    -- At least 4 edges?
    assert(filterGraphs(G, hashTable {"NumEdges" => (4,)}) == G_{0, 1, 4});
///

-- generateBipartiteGraphs
TEST ///
    R = ZZ[a..f];
    -- All bipartite graphs in R.
    assert(#generateBipartiteGraphs(R, Convert => false) == 57);
    -- All bipartite graphs in R with Class1 of size 3.
    assert(#generateBipartiteGraphs(3, R, Convert => false) == 36);
    -- All bipartite graphs in R with Class1 of size 3 and 2 edges.
    assert(#generateBipartiteGraphs(3, 2, R, Convert => false) == 3);
    -- All bipartite graphs in R with Class1 of size 3 and 1-2 edges.
    assert(#generateBipartiteGraphs(3, 1, 2, R) == 4);
///

-- generateGraphs
TEST ///
    R = ZZ[a..f];
    assert(#generateGraphs(R, Convert => false) == 156);
    assert(#generateGraphs(R, Convert => false, OnlyConnected => true) == 112);
    assert(#generateGraphs(7, R) == 24);
    assert(#generateGraphs(7, 8, R, OnlyConnected => true) == 19+22);
///

-- generateRandomGraphs
TEST ///
    R = ZZ[a..f];
    assert(#generateRandomGraphs(10, R) == 10);
    assert(#generateRandomGraphs(17, 1/4, R, Convert => false) == 17);
    assert(#generateRandomGraphs(42, 4, R, Convert => false) == 42);
///

-- generateRandomRegularGraphs
TEST ///
    R = ZZ[a..f];
    assert(#generateRandomRegularGraphs(10, 3, R, Convert => false) == 10);
    -- There is only one regular graph on 6 vertices with regularity degree 5--K6.
    assert(#unique generateRandomRegularGraphs(10, 5, R, Convert => false) == 1);
///

-- graph6ToSparse6
TEST ///
    assert(graph6ToSparse6 "Dhc" == ":DaY_~");
    assert(graph6ToSparse6 "M????????????????" == ":M");
///

-- graphComplement
TEST ///
    R = ZZ[a..e];
    assert(#edges graphComplement cycle R == 5);
    G = graph {a*b, b*c, c*d, d*e};
    assert(graphComplement(G, OnlyIfSmaller => true) == G);
    assert(#edges graphComplement G == 6);
///

-- graphToString
TEST ///
    R = ZZ[a..e];
    assert(graphToString cycle R == "Dhc");
    assert(graphToString ideal (a*b, b*c, c*d, d*e, a*e) == "Dhc");
    assert(graphToString monomialIdeal (a*b, b*c, c*d, d*e, a*e) == "Dhc");
    assert(graphToString "Dhc" == "Dhc");
    assert(graphToString ({{0,1}, {1,2}, {2,3}, {3,4}, {0,4}}, 5) == "Dhc");
    assert(graphToString completeGraph R == "D~{");
    S = ZZ[x_1..x_100];
    assert(graphToString cycle S == "?@chCGGC@?G?_@?@??_?G?@??C??G??G??C??@???G???_??@???@????_???G???@????C????G????G????C????@?????G?????_????@?????@??????_?????G?????@??????C??????G??????G??????C??????@???????G???????_??????@???????@????????_???????G???????@????????C????????G????????G????????C????????@?????????G?????????_????????@?????????@??????????_?????????G?????????@??????????C??????????G??????????G??????????C??????????@???????????G???????????_??????????@???????????@????????????_???????????G???????????@????????????C????????????G????????????G????????????C????????????@?????????????G?????????????_????????????@?????????????@??????????????_?????????????G?????????????@??????????????C??????????????G??????????????G??????????????C??????????????@???????????????G???????????????_??????????????@???????????????@????????????????_???????????????K???????????????@");
///

-- isPlanar
TEST ///
    R = ZZ[a..f];
    assert(isPlanar "Dhc");
    assert(isPlanar cycle R);
    assert(not isPlanar completeGraph R);
    assert(not isPlanar completeMultiPartite (R,2,3));
///

-- neighborhoodComplements
TEST ///
    R = ZZ[a..f];
    assert(#neighborhoodComplements cycle R == #gens R);
///

-- newEdges
TEST ///
    R = ZZ[a..f];
    S = ZZ[a..h];
    -- There are nine pairs of disjoint edges in C6.
    assert(#newEdges(cycle R, S) == 9);
    -- There are 45 pairs of disjoint edges in K6.
    assert(#newEdges(completeGraph R, S) == 45);
///

-- relabelBipartite
TEST ///
    R = ZZ[a..f];
    G = graph {a*d, d*b, b*e, e*c, c*f, f*a};
    assert(relabelBipartite cycle R == G);
///

-- relabelGraph
TEST ///
    R = ZZ[a..f];
    G = cycle R;
    assert(#apply(1..15, i -> relabelGraph(G, i)) == 15);
///

-- removeEdges
TEST ///
    R = ZZ[a..f];
    assert(#removeEdges cycle R == 6);
    assert(#removeEdges completeGraph R == binomial(6,2));
///

-- removeIsomorphs
TEST ///
    R = ZZ[a..f];
    G = {"EhEG", cycle R, completeGraph R, graph {a*d, d*b, b*e, e*c, c*f, f*a}};
    assert(#removeIsomorphs G == 2);
///

-- sparse6ToGraph6
TEST ///
    assert(sparse6ToGraph6 ":DaY_~" == "Dhc");
    assert(sparse6ToGraph6 ":M" == "M????????????????");
///

-- stringToEdgeIdeal
TEST ///
    R = ZZ[a..f];
    assert(stringToEdgeIdeal("EhEG", R) == edgeIdeal cycle R);
    assert(stringToEdgeIdeal("E???", R) == monomialIdeal (0_R));
///

-- stringToGraph
TEST ///
    R = ZZ[a..f];
    assert(stringToGraph("EhEG", R) == cycle R);
    assert(stringToGraph("E???", R) == graph monomialIdeal (0_R));
///

-------------------
-- HappyHappyJoyJoy
-------------------
end

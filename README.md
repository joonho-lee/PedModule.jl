# PedModule

[![Build Status](https://travis-ci.org/reworkhow/PedModule.jl.svg?branch=master)](https://travis-ci.org/reworkhow/PedModule.jl)

###pedigree file
```bash
a 0 0
b 0 0
c a b
```

####Quick-start
```Julia
using PedModule

#set genome information
chrLength, numChr, numLoci, mutRate = 1.0, 1, 100, 0.0
locusInt  = chrLength/numLoci
mapPos    = [0:locusInt:(chrLength-0.0001)];
geneFreq  = fill(0.5,numLoci);

XSim.init(numChr,numLoci,chrLength,geneFreq,mapPos,mutRate)
pop1 = startPop()

#generate populations
ngen,popSize    = 10,10

pop1.popSample(ngen,popSize)
pop2 = pop1.popNew(10);
pop3 = popCross(5,pop1,pop2);

#generate genotypes
M = pop3.getGenotypes()
```



####More

* **homepage**: [QTL.rocks](http://QTL.rocks)
* **Installation**: at the Julia REPL, `Pkg.clone("https://github.com/reworkhow/PedModule.jl.git")`
* **Authors**: [Rohan Fernando](http://www.ans.iastate.edu/faculty/index.php?id=rohan), [Hao Cheng](http://reworkhow.github.io)

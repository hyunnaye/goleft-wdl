version 1.0

import "https://raw.githubusercontent.com/aofarrel/goleft-wdl/revamp/goleft_functions.wdl" as goleft

workflow covstats {



    call goleft.covstats as covstats {
        input:
            inputBamOrCram = oneBamOrCram,
            refGenome = refGenome,
            allInputIndexes = indexesOrLackThereof
	}
}
version 1.0

import "https://raw.githubusercontent.com/aofarrel/goleft-wdl/revamp/goleft_functions.wdl" as goleft

workflow Covstats {

    input {
        File refGenome
        Array[File] bamsOrCrams
        Array[File]? baisOrCrais
    }

    Array[String] emptyArray = ['']

    scatter(oneBamOrCram in bamsOrCrams) {

        # Every instance of covstats gets *all* indexes that the user passes in for the following reasons:
        # * Allows the user to input only some indexes
        # * Allow us to only have to compute indexes that are missing (computing indexes can be expensive + slow)
        # * We don't have to attempt to match bams/crams with their indexes using limited WDL built-ins, instead
        #   we can do that in bash (conveniently also where we can index the bam/cram if the index is missing)
        # * Indexes are small, so localizing a bunch of them isn't a terrible tradeoff

		Array[File] indexesOrLackThereof = select_first([baisOrCrais, emptyArray])

        call goleft.covstats as scatteredCovstats {
            input:
                inputBamOrCram = oneBamOrCram,
                refGenome = refGenome,
                allInputIndexes = indexesOrLackThereof
        }
    
    }

            call goleft.report as report {
            input:
                readLengths = scatteredCovstats.outReadLength,
                coverages = scatteredCovstats.outCoverage,
                filenames = scatteredCovstats.outFilenames
        }

	output {
		File covstatsReport = report.finalOut
        Array[Int] readLengths = scatteredCovstats.outReadLength
        Array[Float] coverages = scatteredCovstats.outCoverage
	}
}
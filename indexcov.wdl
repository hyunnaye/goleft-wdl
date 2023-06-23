version 1.0

import "https://raw.githubusercontent.com/aofarrel/goleft-wdl/0.1.0/goleft_functions.wdl" as goleft

workflow indexcov {

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
		description: "Runs goleft indexcov. If running on Terra download indexDir to read indexcov's HTML output."
    }
	
	input {
		Array[File] bamsOrCrams
		Array[File]? baisOrCrais
		File? refGenome
		File? refGenomeIndex
	}

	Array[String] emptyArray = []

	if(defined(refGenome)) {
        if(!defined(refGenomeIndex)) {
            call goleft.indexRefGenome as indexRefGenome { input: refGenome = refGenome }
        }
	}
    File fai = select_first([refGenomeIndex, indexRefGenome.refIndex])

	scatter(oneBamOrCram in bamsOrCrams) {

        # Every instance of indexcov gets *all* indexes that the user passes in for the following reasons:
        # * Allows the user to input only some indexes
        # * Allow us to only have to compute indexes that are missing (computing indexes can be expensive + slow)
        # * We don't have to attempt to match bams/crams with their indexes using limited WDL built-ins, instead
        #   we can do that in bash (conveniently also where we can index the bam/cram if the index is missing)
        # * Indexes are small, so localizing a bunch of them isn't a terrible tradeoff

		Array[String] indexesOrLackThereof = select_first([baisOrCrais, emptyArray])
        String thisFilename = "${basename(oneBamOrCram)}"
        String thisFilenameMinusCram = sub(thisFilename, "\\.cram", "") # TODO: does \\ get interpreted as backslash or as extension?
        
        if (thisFilename == thisFilenameMinusCram) {
            # After performing a sub() to remove the .cram extension, the basename is unchanged,
            # so this must be a bam file.
            call goleft.indexcovBAM as indexcovBAM {
                input:
                    inputBam = oneBamOrCram,
                    allInputIndexes = indexesOrLackThereof
            }
        }

        if (thisFilename != thisFilenameMinusCram) {
            # After performing a sub() to remove the .cram extension, the basename is changed,
            # so this must be a cram file.
            call goleft.indexcovCRAM as indexcovCRAM {
                input:
                    inputCram = oneBamOrCram,
                    allInputIndexes = indexesOrLackThereof,
                    refGenomeIndex = fai
            }
        }
	}

	output {
		Array[Array[File]?] indexcov_of_bams = indexcovBAM.indexout
		Array[Array[File]?] indexcov_of_crams = indexcovCRAM.indexout
	}
}


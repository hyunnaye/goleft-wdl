version 1.0

import "https://raw.githubusercontent.com/aofarrel/goleft-wdl/0.1.2/goleft_functions.wdl" as goleft

workflow covstats_and_indexcov {

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
		description: "Runs goleft covstats and goleft indexcov, then parses output to extract read length and coverage. If running on Terra download indexDir to read indexcov's HTML output."
    }
	
	input {
		Boolean forceIndexcov = true
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
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

	scatter(oneBamOrCram in inputBamsOrCrams) {

        # Every instance of indexcov/covstats gets *all* indexes that the user passes in for the following reasons:
        # * Allows the user to input only some indexes
        # * Allow us to only have to compute indexes that are missing (computing indexes can be expensive + slow)
        # * We don't have to attempt to match bams/crams with their indexes using limited WDL built-ins, instead
        #   we can do that in bash (conveniently also where we can index the bam/cram if the index is missing)
        # * Indexes are small, so localizing a bunch of them isn't a terrible tradeoff
		Array[String] indexesOrLackThereof = select_first([inputIndexes, emptyArray])

		if (forceIndexcov || length(indexesOrLackThereof) == length(inputBamsOrCrams)) {
            # This block executes if either:
            #   * forceIndexCov is true
			#   * we have one index file per input bam/cram input

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

		call goleft.covstats as covstats {
			input:
				inputBamOrCram = oneBamOrCram,
				refGenome = refGenome,
				allInputIndexes = indexesOrLackThereof
		}
	}

	call goleft.report as report {
		input:
			readLengths = covstats.readLength,
			coverages = covstats.coverage,
			filenames = covstats.filenames
	}

	output {
		File covstats_report = report.finalOut
		Array[Array[File]?] indexcov_of_bams = indexcovBAM.indexout
		Array[Array[File]?] indexcov_of_crams = indexcovCRAM.indexout
	}
}


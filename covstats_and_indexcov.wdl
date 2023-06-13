version 1.0

import "./goleft_functions.wdl" as functions

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
		File? refGenomeIndex # currently unused
	}

	Array[String] emptyArray = []

	if(defined(refGenome)) {
		call functions.indexRefGenome as indexRefGenome { input: refGenome = refGenome }
	}

	scatter(oneBamOrCram in inputBamsOrCrams) {

		Array[String] allOrNoIndexes = select_first([inputIndexes, emptyArray])

		if (forceIndexcov || length(allOrNoIndexes) == length(inputBamsOrCrams)) {

			String thisFilename = "${basename(oneBamOrCram)}"
			String longerIfACram = sub(thisFilename, "\\.cram", "foobarbizbuzz")
			
			if (thisFilename == longerIfACram) {
				# This rings true in the following situations:
				# * This is a bam, and forceIndexCov is true
				# * This is a bam, and we have one index file per input bam/cram input
				# We are hoping that the second case means that the bam has an index file
				# and we won't have to index it ourselves, but this isn't certain
				call functions.indexcovBAM as indexcovBAM {
					input:
						inputBam = oneBamOrCram,
						allInputIndexes = allOrNoIndexes
				}
			}

			if (thisFilename != longerIfACram) {
				call functions.indexcovCRAM as indexcovCRAM {
					input:
						inputCram = oneBamOrCram,
						allInputIndexes = allOrNoIndexes,
						refGenomeIndex = indexRefGenome.refIndex
				}
			}
		}

		call functions.covstats as covstats {
			input:
				inputBamOrCram = oneBamOrCram,
				refGenome = refGenome,
				allInputIndexes = allOrNoIndexes
		}
	}

	call functions.report as report {
		input:
			readLengths = covstats.outReadLength,
			coverages = covstats.outCoverage,
			filenames = covstats.outFilenames
	}

	output {
		File covstats_report = report.finalOut
		Array[Array[File]?] indexcov_of_bams = indexcovBAM.indexout
		Array[Array[File]?] indexcov_of_crams = indexcovCRAM.indexout
	}
}


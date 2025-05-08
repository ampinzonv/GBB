# Documentation for `plot.sh`, `file.sh`, and `utility.sh`

## Functions in `plot.sh`

### `plot_fasta_lengths`
Generates a plot of sequence lengths from a FASTA file.

#### Purpose
This function visualizes the distribution of sequence lengths in a FASTA file using different plot types.

#### Usage
```bash
get_fasta_length file.fasta | plot_fasta_lengths [--format png|pdf|svg] [--mode bars|histogram|boxplot|cdf|auto] [--output filename]
```

#### Arguments
- `--format`: Specifies the output format of the plot. Supported formats are `png`, `pdf`, and `svg`. Default is `png`.
- `--output`: Specifies the name of the output file (without extension). Default is `fasta_lengths`.
- `--mode`: Specifies the type of plot to generate. Options are:
  - `bars`: Bar plot of sequence lengths.
  - `histogram`: Histogram of sequence lengths.
  - `boxplot`: Boxplot of sequence lengths.
  - `cdf`: Cumulative distribution function (CDF) of sequence lengths.
  - `auto`: Automatically selects `bars` for ≤100 sequences, otherwise `histogram`.

#### Example
```bash
get_fasta_length test.fasta | plot_fasta_lengths --format pdf --mode histogram --output lengths_plot
```

---

## Functions in `file.sh`

### `get_fasta_header`
Extracts the headers from a FASTA file.

#### Purpose
This function retrieves all the headers (lines starting with `>`) from a FASTA file.

#### Usage
```bash
get_fasta_header <file.fasta>
cat file.fasta | get_fasta_header
```

---

### `get_fasta_id`
Extracts the sequence IDs from a FASTA file.

#### Purpose
This function retrieves only the sequence IDs (without the `>` symbol) from the headers of a FASTA file.

#### Usage
```bash
get_fasta_id <file.fasta>
cat file.fasta | get_fasta_id
```

---

### `get_fasta_seq`
Extracts the sequences from a FASTA file.

#### Purpose
This function retrieves only the sequence data, excluding the headers, from a FASTA file.

#### Usage
```bash
get_fasta_seq <file.fasta>
cat file.fasta | get_fasta_seq
```

---

### `get_fasta_length`
Calculates the length of each sequence in a FASTA file.

#### Purpose
This function outputs the sequence ID and its length in a tab-separated format.

#### Usage
```bash
get_fasta_length <file.fasta>
cat file.fasta | get_fasta_length
```

---

### `fastq_to_fasta`
Converts a FASTQ file to a FASTA file.

#### Purpose
This function converts the sequence and header lines from a FASTQ file to FASTA format.

#### Usage
```bash
fastq_to_fasta <file.fastq>
cat file.fastq | fastq_to_fasta
```

---

### `split_multiple_fasta`
Splits a multi-sequence FASTA file into individual FASTA files.

#### Purpose
This function creates separate FASTA files for each sequence in the input file. The output files are named based on the sequence IDs.

#### Usage
```bash
split_multiple_fasta <file.fasta> [output_directory]
```

---

### `fastq_stats`
Calculates statistics for a FASTQ file.

#### Purpose
This function outputs statistics such as the number of sequences, total length, minimum/maximum length, average length, and quality scores (Q20 and Q30).

#### Usage
```bash
fastq_stats <file.fastq>
cat file.fastq | fastq_stats
```

---

### `fasta_stats`
Calculates statistics for a FASTA file.

#### Purpose
This function outputs statistics such as the number of sequences, total length, minimum/maximum length, average length, and N50 value.

#### Usage
```bash
fasta_stats <file.fasta>
cat file.fasta | fasta_stats
```

---

### `get_fasta_entry`
Extracts a specific sequence entry from a FASTA file by its ID.

#### Purpose
This function retrieves the header and sequence for a specific ID from a FASTA file.

#### Usage
```bash
get_fasta_entry <file.fasta> <sequence_id>
cat file.fasta | get_fasta_entry <sequence_id>
```

---

### `get_fasta_range`
Extracts specific subsequences from a FASTA file based on a list of ranges.

#### Purpose
This function retrieves subsequences from a FASTA file based on specified start and end positions.

#### Usage
```bash
get_fasta_range <file.fasta> <range1-range2,...>
cat file.fasta | get_fasta_range <range1-range2,...>
```

---

## Functions in `utility.sh`

### `get_list`
Generates a sorted list of unique values from a file, with optional frequency counts.

#### Purpose
This function processes a file or standard input to produce a sorted list of unique values. If the `--frequency` flag is provided, it also calculates the frequency and percentage of each value.

#### Usage
```bash
get_list [--frequency] <file | -> 
cat file | get_list [--frequency]
```

#### Arguments
- `--frequency`: If provided, the function outputs the frequency and percentage of each unique value.
- `<file>`: The input file to process. If omitted or set to `-`, the function reads from standard input.

#### Example
```bash
# Generate a sorted list of unique values
get_list input.txt

# Generate a sorted list with frequency and percentage
get_list --frequency input.txt
```

---
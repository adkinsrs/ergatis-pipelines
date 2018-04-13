<?php
	ini_set('display_errors', 'On');
	error_reporting(E_ALL | E_STRICT);
	

	$formFieldsArr = Array("output_dir" => "Output directory", "log_file" => "Log file", "r_input" => "Input File");
	
	$args = '';
	$args .= "--data_directory=/mnt/output_data "; # By default gather output for use in LGTView
	$local_dir = "/usr/local/scratch/pipeline_dir";
	$ergatis_config = "/var/www/html/ergatis/cgi/ergatis.ini";
	$errFlag = 0;

	# Shouldn't hard-code things but this is just being used in the Docker container
	$repo_root = "/opt/projects/lgtseek";

# The first thing to do is to create the config and layout files for the pipeline
	if (isset($_POST['bsubmit'])) {
		$dir = create_pipeline_dir($local_dir);
		$formValuesArr['output_dir']['default'] = $dir;
		$formValuesArr['output_dir']['error'] = 0;
		$args .= "--output_directory $dir ";

		$formValuesArr['log_file']['error'] = 0;
		if (isset($dir)) {
			$formValuesArr['log_file']['create'] = $dir."/create_lgt_pipeline.log";
			$formValuesArr['log_file']['run'] = $dir."/run_lgt_pipeline.log";
			$args .= "--log {$formValuesArr['log_file']['create']} ";
		} else {
			$errFlag++;
			$formValuesArr['log_file']['error'] = $errFlag;
			$formValuesArr['log_file']['msg'] = "Could not create log file";
		}

		if ( !empty($_POST['tsra']) ) {
			$args .= "--sra_id " . trim($_POST['tsra']) . " ";
			$formValuesArr['r_input']['error'] = 0;
		} elseif ( !empty($_POST['ibam']) ) {
			$bam = trim($_POST['ibam']);
			$bam_list = '/mnt/input_data/bam.list';
			create_list_file($_FILES['ibam'], $bam_list);
			$args .= "--bam_input $bam_list ";
			$formValuesArr['r_input']['error'] = 0;
		} elseif ( !empty($_POST['ifastq']) ) {
			$fastq = trim($_POST['ifastq']);
			$fastq_list = '/mnt/input_data/fastq.list';
			create_list_file($_FILES['ifastq'], $fastq_list);
			$args .= "--fastq_input $fastq_list ";
			$formValuesArr['r_input']['error'] = 0;
		} else {
			$errFlag++;
			$formValuesArr['r_input']['error'] = $errFlag;
			$formValuesArr['r_input']['msg'] = "An SRA ID, FASTQ input path, or BAM input path is required.";
		}

		if ( !empty($_POST['idonor']) ) {
			$donor = trim($_POST['idonor']);
			$donor_list = '/mnt/input_data/donor.list';
			create_list_file($_FILES['idonor'], $donor_list);
			$args .= "--donor_reference $donor_list ";
		} else {
			if ( trim($_POST['r_usecase']) == 'case1' || trim($_POST['r_usecase']) == 'case2' || trim($_POST['r_usecase']) == 'case3' ){
				$errFlag++;
				$formValuesArr['r_input']['error'] = $errFlag;
				$formValuesArr['r_input']['msg'] = "No donor input file found.";
			}
		}
		if ( !empty($_POST['irecipient']) ) {
			$recipient = trim($_POST['irecipient']);
			$recipient_list = '/mnt/input_data/recipient.list';
			create_list_file($_FILES['irecipient'], $recipient_list);
			$args .= "--host_reference $recipient_list ";
		} else {
			if ( trim($_POST['r_usecase']) == 'case1' || trim($_POST['r_usecase']) == 'case2' || trim($_POST['r_usecase']) == 'case4' ){
				$errFlag++;
				$formValuesArr['r_input']['error'] = $errFlag;
				$formValuesArr['r_input']['msg'] = "No recipient input file found.";
			}
		}

		if ( $_POST['c_build'] == 1 ) {
			$args .= "--build_indexes ";
		}


		if ( trim($_POST['r_usecase']) == 'case2' ){
			$args .= "--lgt_infected ";
		}
	}

	if ($errFlag == 0) {
		exec("/usr/bin/perl ./perl/create_lgt_pipeline_config.pl $args --template_directory /opt/ergatis/pipeline_templates", $exec_output, $exit_status);
		#echo "/usr/bin/perl ./perl/create_lgt_pipeline_config.pl $args --template_directory /opt/ergatis/pipeline_templates";

		if ($exit_status > 0) {
			$output_string = implode("\n", $exec_output);
			echo "<li><font color=\"red\">Error in Perl script.  Please contact system administrator!</font></li>";
			echo "$output_string";
			echo "<br>";
			exit(1);
		}
	} else {
		# Exact code as in lgt_pipeline_complete.php ... need to eliminate redundancy later
		echo "<br>";
		echo "<h3>Hit the browser's Back button and resolve the following errors to proceed:</h3>";
		echo "<ul>";
		foreach ($formFieldsArr as $formField => $val) {
			if ( $formValuesArr[$formField]['error'] > 0) {
				echo "<li><font color=\"red\">ERROR !! {$formValuesArr[$formField]['msg']}</font></li>";
			}
		}
		echo "</ul>";
		exit(1);
	}

	# Find our newly created pipeline_config and layout files, and create the pipeline and run
	$pipeline_config = `find {$formValuesArr['output_dir']['default']} -name "*.config" -type f`;
	$pipeline_layout = `find {$formValuesArr['output_dir']['default']} -name "*.layout" -type f`;

	if (!( isset($pipeline_config) && isset($pipeline_layout) )) {
		echo "<font color='red'>Error creating pipeline.config and pipeline.layout files</font><br>";
		exit(1);
	}

	$p_config = trim($pipeline_config);
	$p_layout = trim($pipeline_layout);

	if (!file_exists( $p_config )){
		echo "<li><font color=\"red\">ERROR !! $p_config does not appear to exist!</font></li>";
		exit(1);
	}
	if (!file_exists( $p_layout )){
		"<li><font color=\"red\">ERROR !! $p_layout does not appear to exist!</font></li>";
		exit(1);
	}

	# Creates a list file out of the uploaded file array and returns it
	function create_list_file($files, $list_file) {
		# Ignore BWA index extensions
        $ignored_extensions = ['.amb', '.ann', '.bwt', '.pac', '.sa'];

		$fh = fopen($list_file, 'w');
        foreach ($files['tmp_name'] as $file) {
			$fileparts = pathinfo($file);
			if (! in_array($fileparts['extension'], $ignored_extensions) ){
				fwrite($fh, $file . "\n");
		  	}
		}
		fclose($fh);
	}

	function create_pipeline_dir ($local_dir) {
		$dir_num = mt_rand(1, 999999);
		$temp_num = str_pad($dir_num, 6, "0", STR_PAD_LEFT);
		$dir = $local_dir.$temp_num;
		if (!file_exists($dir)) {
			if(!(mkdir($dir, 0777, true))) {
				echo "<font color='red'>Error creating temporary pipeline directory $dir</font><br>";
				exit(1);
			} else {
				return($dir);
			}
		} else {
			create_pipeline_dir();
		}
	}
?>

<?php
$page_title = 'Pipeline Builder - Step 1';
$extra_head_tags = '<script type="text/javascript" src="./js/MiscFunctions.js"></script>';
include_once('header.php');
/*
<html>
  <head>
  </head>
  <body>
    <div id='page_container'>
      <div id='content_container'>
*/  ?>

<!-- HTML5 coding style suggests to keep indenting to a minimum and seperate code blocks with blank lines -->
<form id='lgt_pipeline_step1_form' method="post" action="lgt_pipeline_complete.php" enctype="multipart/form-data">
<br>

<fieldset name="Step1">
<legend class="legend">STEP 1: Select the use-case for this pipeline</legend>
<label><input type="radio" name="r_usecase" id="r_case1" value="case1" onclick="SetUpRefFields()">Use Case 1 - Good donor and good LGT-free recipient</label><br>
<label><input type="radio" name="r_usecase" id="r_case2" value="case2" onclick="SetUpRefFields()">Use Case 2 - Good donor but LGT-infected recipient</label><br>
<label><input type="radio" name="r_usecase" id="r_case3" value="case3" onclick="SetUpRefFields()">Use Case 3 - Good donor but unknown recipient</label><br>
<label><input type="radio" name="r_usecase" id="r_case4" value="case4" onclick="SetUpRefFields()">Use Case 4 - Good recipient but unknown donor</label><br>
</fieldset>

<fieldset name="Step2" style="display:none">
<legend class="legend">STEP 2: Select an input file type <sup><a href='./help.php#form' target='_blank'>?</a></sup></legend>
<label><input type="radio" name="r_input" id="rbam" onclick="SetUpInputFields()">BAM</label><br>
<label><input type="radio" name="r_input" id="rfastq" onclick="SetUpInputFields()">FASTQ</label><br>
<label><input type="radio" name="r_input" id="rsra" onclick="SetUpInputFields()">SRA</label><br>
</fieldset>

<fieldset name="Step3" style="display:none">
<legend class="legend">STEP 3: Provide the necessary file information <sup><a href='./help.php#form' target='_blank'>?</a></sup></legend>
<p id="multipleFileYes" style="display:none;">Note: Hold CTRL to select multiple files for input. Hold SHIFT to select all files between two clicked files.</p>
<p id="multipleFileNo">It appears your browser does not allow for multiple file input.  You will only be able to have one input per field.</p>
<div id="ddonor">
<label for="idonor">Donor reference file(s)</label><br>
<input type="input" name="tdonor[]" id="tdonor" class="textbox" multiple value=''><br><br>
</div>
<div id="drecipient">
<label for="irecipient">Recipient reference file(s)</label><br>
<input type="input" name="trecipient[]" id="trecipient" class="textbox" multiple value=''><br><br>
</div>
<div id="drefseq">
<label for="irefseq">RefSeq reference file(s)</label><br>
<input type="input" name="trefseq[]" id="trefseq" class="textbox" multiple value=''><br><br>
</div>
<div id="dbam">
<label for="ibam">BAM file(s)</label><br>
<input type="input" name="tbam[]" id="tbam" class="textbox" multiple value=''><br>
</div>
<div id="dfastq">
<label for="ifastq">FASTQ file(s)</label><br>
<input type="input" name="tfastq" id="tfastq" class="textbox" multiple value=''><br>
</div>
<div id="dsra">
<label for="tsra">SRA ID</label><br>
<input type="text" name="tsra" id="tsra" class="textbox" value=''><br>
</div>
<label><input type="checkbox" name="c_build" value=1 >Check to Build BWA Indexes.</label>
</fieldset>

<br>
<input type="submit" name="bsubmit" value="Submit">
<input type="reset" name="breset" onclick="ResetForm()" value="Reset">
</form>

<?php
include_once('footer.php');
/*    </div>
    </div>
  </body>
</html>
*/
?>
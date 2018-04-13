// Reset the form to its original appearance
function ResetForm() {
	var FormName = document.forms.namedItem("lgt_pipeline_step1_form");
	FormName.Step2.style.display = "none";
	FormName.Step3.style.display = "none";
}

// Clear the text input fields
function ResetText() {
	var FormName = document.forms.namedItem("lgt_pipeline_step1_form");
	var textFields = ["tsra", "tfastq", "tbam", "tdonor", "trecipient", "tbac_acc", "tbac_ref", "teuk_acc", "teuk_ref"];
    for (var i in textFields) {
		field = FormName.elements[ textFields[i] ];
       	field.value = field.defaultValue;
	}
}

// When UseCase radio button is clicked, bring up the reference text fields
function SetUpRefFields() {
	var FormName = document.forms.namedItem("lgt_pipeline_step1_form");
	FormName.Step2.style.display = "block";
	if (document.getElementById("r_case1").checked || document.getElementById("r_case2").checked) {
		document.getElementById('ddonor').style.display = "block";
		document.getElementById('drecipient').style.display = "block";
	} else if (document.getElementById("r_case3").checked) {
		document.getElementById('ddonor').style.display = "block";
		document.getElementById('drecipient').style.display = "none";
	} else if (document.getElementById("r_case4").checked) {
		document.getElementById('ddonor').style.display = "none";
		document.getElementById('drecipient').style.display = "block";
	}
	ResetText();
}

// When InputType radio button is clicked, bring up the correct input text field
function SetUpInputFields() {
	var FormName = document.forms.namedItem("lgt_pipeline_step1_form");
	FormName.Step3.style.display = "block";
	if (document.getElementById("rbam").checked) {
		document.getElementById('dbam').style.display = "block";
		document.getElementById('dfastq').style.display = "none";
		document.getElementById('dsra').style.display = "none";
	} else if (document.getElementById("rfastq").checked) {
		document.getElementById('dbam').style.display = "none";
		document.getElementById('dfastq').style.display = "block";
		document.getElementById('dsra').style.display = "none";
	} else if (document.getElementById("rsra").checked) {
		document.getElementById('dbam').style.display = "none";
		document.getElementById('dfastq').style.display = "none";
		document.getElementById('dsra').style.display = "block";
	}
	//ResetText();
}

<!DOCTYPE html> 

<html>
  <head>
    <title><?php echo $page_title; ?> - Ergatis</title>
    <meta charset="utf-8">
    <link rel="stylesheet" type="text/css" href="./css/common.css">
    <link rel="stylesheet" type="text/css" href="./css/header.css">
    <link rel="stylesheet" type="text/css" href="./css/monitor.css">
    <link rel="stylesheet" type="text/css" href="./css/index.css">
    <link rel="stylesheet" type="text/css" href="./css/forms.css">
    <link rel="stylesheet" type="text/css" href="./css/config_file.css">
    <?php if ( isset($extra_head_tags)) {
      echo $extra_head_tags;
    } ?>
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
    <![endif]-->
  </head>

  <body>
    <div id='page_header'>
      <div id='title_container'>
        <span id='page_title'>LGTSeek Pipeline Builder</span>
      </div>
    </div>
    <div id='sub_nav_container'>
      <ul id='sub_nav_elements'>
        <li><a href='lgt_pipeline_step1.php'>Home</a></li>
        <li><a href="help.php">Help</a></li>
      </ul>
    </div>

    <div id='page_container'>
      <div id='content_container'>

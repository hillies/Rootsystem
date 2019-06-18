<?php

// --------------------- Variables --------------------------------

$server = "0.0.0.0";
$username = "user";
$password = "Password";
$dbname = "testdb";

// --------------------- Connect to Database --------------------------------

$con = mysqli_connect($server, $username, $password, $dbname);

// --------------------- Check for database connection Error --------------------------------

if (!$con) {
	echo "failed to connect to server";
}

?>

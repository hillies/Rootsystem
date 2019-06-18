<?php

require("connect.php");

// ---------------------- Query ------------------------------------------

$query = "INSERT INTO accounts (name, surname, contact, email) VALUES('quintin', 'hills', '0844739999', 'hillsq@hotmail.com')";
mysqli_query($link, $query);

?>

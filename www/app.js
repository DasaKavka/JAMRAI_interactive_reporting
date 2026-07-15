// app.js — page-level scripts for the JAMRAI dashboard
// (extracted from app.R so the R, HTML, JS and CSS stay separated)

// Append the dashboard subtitle into the header navbar (only once).
$(document).ready(function () {
  if ($("header nav .myClass").length === 0) {
    $("header").find("nav").append(
      '<span class="myClass"> <br/>One Health antimicrobial resistance pilot dashboard</span>'
    );
  }
});

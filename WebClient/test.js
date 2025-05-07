function setDefaultConnect(){    
  sessionStorage['connect'] = 0;  
}

function incrementConnect(){
  var currentValue = getConnect();
  sessionStorage['connect'] = currentValue + 1;  
}

function getConnect() {
   return parseInt(sessionStorage["connect"]);
}

function onGET_jwt(httpStatus, response){
  var currentValue = getConnect();
  $('#console').append('onGET_jwt response jwt ' + currentValue + ' :\n'+ response);
}

function onGET_httpResult(httpStatus, response){
  $('#consoleJWT').empty();
  $('#consoleJWT').append('onGET_jwt response jwt :\n'+ response);
}

function getvalidjwt(){
	
 var xhr = new XMLHttpRequest({strictSSL: false});
   
   xhr.onreadystatechange = function(event) {
      if (this.readyState === XMLHttpRequest.DONE) {
        if (this.status === 200) {
            tmp = JSON.parse(xhr.responseText);
			sessionStorage.setItem("jwt",tmp.jwt);
        } else {
            tmp = 'error:\n' + xhr.statusText;
        }
		$('#consoleJWT').empty();
		$('#consoleJWT').append('New jwt :\n'+ tmp.jwt);
      }	  
    };

    jwt = sessionStorage["jwt"];
    username = $("#login").val();
	mpass = $("#mdp").val();
	serverIP = $("#server").val();
	uriroot = $("#mainuri").val();
	
    xhr.open('GET', "http://" + serverIP + "/" + uriroot + "/RefreshToken?username=" + username + "&password=" + mpass, false);
	xhr.setRequestHeader('Authorization', ' bearer ' + jwt);	
    xhr.send(null);    	
}

$("#submit").click(function(){
 setDefaultConnect(); 
 
 var xhr = new XMLHttpRequest({strictSSL: false});
    xhr.onreadystatechange = function(event) {
      if (this.readyState === XMLHttpRequest.DONE) {
        if (this.status === 200) {
            tmp = JSON.parse(xhr.responseText);
			sessionStorage.setItem("jwt",tmp.jwt);
        } else {
            tmp = xhr.statusText;
        }
		$('#console').empty();
		$('#consoleJWT').empty();
		$('#consoleJWT').append('jwt :\n'+ tmp.jwt);
      }	  
    };

    username = $("#login").val();
	mpass = $("#mdp").val();
	serverIP = $("#server").val();
	uriroot = $("#mainuri").val();
	
	xhr.open('GET', "http://" + serverIP + "/" + uriroot + "/Auth?username=" + username + "&password=" + mpass, true);
    xhr.send(null);    
});

$("#submit2").click(function(){
 var xhr = new XMLHttpRequest();
 let i = 0;
 for (i = 0; i < 1000; i++) {
   getvalidjwt();
   tmp = sessionStorage.getItem("jwt");  
  console.log('from sess. storage: ', tmp);
  $('#console').empty();
  incrementConnect();
  GET_jwt(tmp, onGET_jwt);  
 }
   
  getvalidjwt();
  tmp = sessionStorage.getItem("jwt");  
  console.log('from sess. storage: ', tmp);
  $('#console').empty();
  incrementConnect();
  GET_jwt(tmp, onGET_jwt);  
});

$("#submitjwt").click(function(){
 
 var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function(event) {
      if (this.readyState === XMLHttpRequest.DONE) {
        if (this.status === 200) {
            tmp = 'success : \n' + xhr.responseText;
        } else {
            tmp = 'error:\n' + xhr.statusText;
        }
		$('#consoleJWT').empty();
		$('#consoleJWT').append('jwt :\n'+ tmp);
      }	  
    };

    jwt = sessionStorage.getItem("jwt");
	serverIP = $("#server").val();
	uriroot = $("#mainuri").val();
	
	xhr.open('GET', "http://" + serverIP + "/" + uriroot + "/IsValidToken", true);
	xhr.setRequestHeader('Authorization', ' bearer ' + jwt);
    xhr.send(null);    
});

$("#refreshjwt").click(function(){
 
 var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function(event) {
      if (this.readyState === XMLHttpRequest.DONE) {
        if (this.status === 200) {
            tmp = JSON.parse(xhr.responseText);
			sessionStorage.setItem("jwt",tmp.jwt);
        } else {
            tmp = 'error:\n' + xhr.statusText;
        }
		$('#consoleJWT').empty();
		$('#consoleJWT').append('jwt :\n'+ tmp.jwt);
      }	  
    };

    jwt = sessionStorage.getItem("jwt");
    username = $("#login").val();
	mpass = $("#mdp").val();
	serverIP = $("#server").val();
	uriroot = $("#mainuri").val();
	
	xhr.open('GET', "http://" + serverIP + "/" + uriroot + "/RefreshToken?username=" + username + "&password=" + mpass, true);
	xhr.setRequestHeader('Authorization', ' bearer ' + jwt);
    xhr.send(null);    
});

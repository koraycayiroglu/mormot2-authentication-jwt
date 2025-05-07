
var GET_jwt = function(jwt,callback){

  var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function(event) {
      // XMLHttpRequest.DONE === 4
      if (this.readyState === XMLHttpRequest.DONE) {
        if (this.status === 200) {
            response = xhr.responseText;
        } else {
            response = xhr.statusText;
        }
		callback(200, response);
      }	  
    };
	arequest = $("#request").val();	
	aserver =  $("#server").val();
	
	xhr.open('GET', "http://" + aserver + "/root/" + arequest, true);
    xhr.setRequestHeader('Authorization', ' bearer ' + jwt);
    xhr.send(null);    
	

}

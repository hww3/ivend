#!NOMODULE
#include <ivend.h>

inherit "roxenlib";

constant module_name = "Signio Payment Processing";
constant module_type = "addin";    

mixed signio_handler(string mode, object id){

string retval;

ADMIN_FLAGS=NO_BORDER;


return retval;

}

/*
string tag_upsell(string tag_name, mapping args,
                  object id, mapping defines) {

}
*/

mixed query_tag_callers(){

  return ([ ]);

}

mixed query_event_callers(){

  return ([ ]);

}

mixed register_admin(){

  return ({
	([ "mode": "menu.main.Store_Administration.Signio_Setup",
		"handler": signio_handler,
		"security_level": 0 ])
	});
}



mixed query_preferences(object id){

return ({
                
        ({"host", "Signio Processor Host",
        "Hostname of Signio internet payment host.",
        VARIABLE_STRING,
        "test.paymentnet.com"
        }),

        ({"port", "Signio Processor Port",
        "Port Number on Signio internet payment host.",
        VARIABLE_STRING,
        "443"
        }),

        ({"account", "Signio Account Number",
        "Your account number with Signio.",
        VARIABLE_STRING,
        ""
        }),

        ({"password", "Signio Account Password",
        "Your account password.",
        VARIABLE_STRING,
        ""
        })



});

}

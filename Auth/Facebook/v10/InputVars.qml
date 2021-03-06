import QtQuick 2.5
QtObject {
    property string appId            : "1587909424854598"
    property string appSecret        //: "6aa74dc057a670a8300f49691cea248a"   //is used to make session long lived?
    property string authUrl          : "https://www.facebook.com/dialog/oauth"
    property string redirectUrl      : "https://www.facebook.com/connect/login_success.html"    //cause we have a custom loginflow, ya dig?
    property var    permissions      : ["public_profile","email","user_friends"]
    property string fbhost           : "https://graph.facebook.com"

    property string appAuthenticatedKey : 'code'
    property bool   readyFlag : false //turn this on for the webview to load the url!
}

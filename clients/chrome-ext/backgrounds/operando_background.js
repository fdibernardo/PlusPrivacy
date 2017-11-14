/*
 * Copyright (c) 2016 ROMSOFT.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the The MIT License (MIT).
 * which accompanies this distribution, and is available at
 * http://opensource.org/licenses/MIT
 *
 * Contributors:
 *    RAFAEL MASTALERU (ROMSOFT)
 * Initially developed in the context of OPERANDO EU project www.operando.eu
 */

var webRequest = chrome.webRequest;
var HEADERS_TO_STRIP_LOWERCASE = [
    'content-security-policy',
    'x-frame-options'
];

var DependencyManager = require("DependencyManager").DependencyManager;
var bus = require("bus-service").bus;

webRequest.onHeadersReceived.addListener(
    function (details) {
        return {
            responseHeaders: details.responseHeaders.filter(function (header) {
                return HEADERS_TO_STRIP_LOWERCASE.indexOf(header.name.toLowerCase()) < 0;
            })
        };
    }, {
        urls: ["<all_urls>"]
    }, ["blocking", "responseHeaders"]);


chrome.runtime.onMessage.addListener(function (message, sender, sendResponse) {

    if (message.message === "getCookies") {
        if (message.url) {
            chrome.cookies.getAll({url: message.url}, function (cookies) {
                sendResponse(cookies);
            });

            return true;
        }
    }

    if (message.message === "waitForAPost") {
        if (message.template) {

            webRequest.onBeforeRequest.addListener(function waitForPost(request) {
                    if (request.method == "POST") {
                        var requestBody = request.requestBody;
                        if (requestBody.formData) {
                            var formData = requestBody.formData;
                            for (var prop in message.template) {
                                if (formData[prop]) {
                                    if(formData[prop] instanceof Array){
                                        message.template[prop] = formData[prop][0];
                                    }
                                    else{
                                        message.template[prop] = formData[prop];
                                    }
                                }
                            }

                            webRequest.onBeforeRequest.removeListener(waitForPost);
                            sendResponse ({template:message.template});
                        }
                    }

                },
                {urls: ["*://www.facebook.com/*"]},
                ["blocking", "requestBody"]);
        }
        return true;
    }

});

webRequest.onBeforeSendHeaders.addListener(function(details) {

        var referer = "";
        for (var i = 0; i < details.requestHeaders.length; ++i) {
            var header = details.requestHeaders[i];
            if (header.name === "X-Alt-Referer") {
                referer = header.value;
                details.requestHeaders.splice(i, 1);
                break;
            }
        }
        if (referer !== "") {
            for (var i = 0; i < details.requestHeaders.length; ++i) {
                var header = details.requestHeaders[i];
                if (header.name === "Referer") {
                    details.requestHeaders[i].value = referer;
                    break;
                }
            }
        }

            details.requestHeaders.some(function(header, i){
                if(header.name === "PlusPrivacyHeaders"){
                    var customHeaders = JSON.parse(header.value);
                    if(customHeaders instanceof Array){
                        customHeaders.forEach(function(header){
                            details.requestHeaders.push(header);
                        })
                    }

                    header.name = "Referrer-Policy",
                        header.value = "origin"
                    //details.requestHeaders.splice(i,1);
                    return true;
                }
                return false;
            });

        return {requestHeaders: details.requestHeaders};

    },
    {urls: ["<all_urls>"]},
    ["blocking", "requestHeaders"]);


webRequest.onBeforeSendHeaders.addListener(
    function(details) {
        if(details['url'].indexOf("https://www.facebook.com/ajax/settings/apps/delete_app.php")>=0){

            for (var i = 0; i < details.requestHeaders.length; ++i) {
                if (details.requestHeaders[i].name === "Origin") {
                    details.requestHeaders[i].value = "https://www.facebook.com";
                    break;
                }
            }
            details.requestHeaders.push({
                name:"referer",
                value:"https://www.facebook.com/settings?tab=applications"
            });
        }

        return {requestHeaders: details.requestHeaders};
    },
    {urls: ["*://www.facebook.com/*"]},
    ["blocking", "requestHeaders"]);


chrome.webRequest.onHeadersReceived.addListener(
    function(details) {
        var feedbackFormUrl = CONSTANTS.FEEDBACK_FORM_URL + "/formResponse";
        if(details.url.indexOf(feedbackFormUrl)>-1){
            swarmHub.startSwarm("notification.js","registerInZone", "FEEDBACK_SUBMITTED");
        }
        return {cancel: false};
    },
    {urls: ["*://docs.google.com/*"]},
    ["blocking"]);


var getDeviceIdAction = bus.getAction("getDeviceId");
getDeviceIdAction(function(deviceId){
    console.log(deviceId);
    chrome.runtime.setUninstallURL(ExtensionConfig.UNINSTALL_URL+deviceId);
});

package eu.operando.activity;


import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebViewClient;
import android.widget.RelativeLayout;

import eu.operando.R;
import eu.operando.customView.MyWebViewClient;
import eu.operando.utils.WebAppI;

/**
 * Created by Alex on 3/26/2018.
 */

public class FacebookApps extends SocialNetworkAppsBaseWebActivity {

    private final String MOBILE_URL = "https://m.facebook.com/privacy/touch/apps/list/?tab=all";
    private final String IS_LOGGED_JS_FILE = "facebook_is_logged.js";
    private final String APPS_JS_FILE = "facebook_apps.js";

    @Override
    public String getURL_MOBILE() {
        return MOBILE_URL;
    }

    @Override
    protected String getURL() {
        return MOBILE_URL;
    }

    @Override
    public WebViewClient getWebViewClient() {
        return new MyWebViewClient(this);
    }

    @Override
    public WebAppI getWebAppInterface() {
        return new WebAppInterface();
    }

    @Override
    public String getJsFile() {
        return APPS_JS_FILE;
    }

    @Override
    public String getIsLoggedJsFile() {
        return IS_LOGGED_JS_FILE;
    }


    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_facebook_web_view);
        initUI();
        initData();

    }

    @Override
    public void initData() {

        myWebView.setVisibility(View.INVISIBLE);
        RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        lp.setMargins(0, 0, 0, 0);
        frameLayout.setLayoutParams(lp);

        initProgressDialog();
    }

    public void startInjecting() {

        if (!shouldInject) {

//            setAgent();
            myWebView.loadUrl(MOBILE_URL);

            if (android.os.Build.VERSION.SDK_INT >= 21) {
                CookieManager.getInstance().setAcceptThirdPartyCookies(myWebView, true);
            } else {
                CookieManager.getInstance().setAcceptCookie(true);
            }
            initProgressDialog();
            shouldInject = true;

        }
    }

    @Override
    public void onPageListener() {

        synchronized (mutex) {
            if (!triggered) {
                injectScriptFile(getIsLoggedJsFile());
            } else {
                if (shouldInject) {
                    injectScriptFile("test_jquery.js");
                    if (webAppInterface.getIsJQueryLoaded() == 0) {
                        injectScriptFile("jquery214min.js");
                    }

                    shouldInject = false;
                    injectScriptFile("RegexUtils.js");
                    injectScriptFile(getJsFile());
                }
            }
        }
    }

    protected void cancelProgressDialog() {
        if (!isFinishing()) {
            frameLayout.setVisibility(View.INVISIBLE);
            myWebView.setVisibility(View.VISIBLE);
        }
    }

    private void startSnAppListActivity(String apps) {

        Intent starter = new Intent(getApplicationContext(), SocialNetworkAppsListActivity.class);
        starter.putExtra("APPS", apps);
        startActivity(starter);

    }

    public class WebAppInterface extends WebAppI {

        private int index = 0;

        @JavascriptInterface
        public void showToast(String message) {
            Log.e("msg from the dark side", message);
        }

        @JavascriptInterface
        public void onFinishedLoadingCallback(final String apps) {

            Log.e("apps", apps);

            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (!isFinishing()) {
                        finish();
                        startSnAppListActivity(apps);
                    }
                }
            });
        }

        @JavascriptInterface
        public void isLogged(int isLogged) {
            Log.e("WebAppI isLogged", String.valueOf(isLogged));
            if (isLogged == 1) {
                triggered = true;
                myWebView.post(new Runnable() {
                    @Override
                    public void run() {
                        startInjecting();
                    }
                });
            } else {
                cancelProgressDialog();
            }
        }
    }

}

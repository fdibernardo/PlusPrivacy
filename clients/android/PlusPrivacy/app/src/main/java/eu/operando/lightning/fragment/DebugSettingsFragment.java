package eu.operando.lightning.fragment;

import android.app.Activity;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceFragment;
import android.preference.SwitchPreference;
import android.support.annotation.NonNull;

import javax.inject.Inject;

import eu.operando.PlusPrivacyApp;
import eu.operando.R;
import eu.operando.lightning.preference.PreferenceManager;
import eu.operando.lightning.utils.Utils;

public class DebugSettingsFragment extends PreferenceFragment implements Preference.OnPreferenceClickListener, Preference.OnPreferenceChangeListener {

    private static final String LEAK_CANARY = "leak_canary_enabled";

    @Inject PreferenceManager mPreferenceManager;

    private SwitchPreference mSwitchLeakCanary;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        PlusPrivacyApp.getAppComponent().inject(this);
        addPreferencesFromResource(R.xml.preference_debug);

        mSwitchLeakCanary = (SwitchPreference) findPreference(LEAK_CANARY);
        mSwitchLeakCanary.setChecked(mPreferenceManager.getUseLeakCanary());
        mSwitchLeakCanary.setOnPreferenceChangeListener(this);
    }


    @Override
    public boolean onPreferenceClick(@NonNull Preference preference) {
        return false;
    }

    @Override
    public boolean onPreferenceChange(@NonNull Preference preference, @NonNull Object newValue) {
        switch (preference.getKey()) {
            case LEAK_CANARY:
                boolean value = Boolean.TRUE.equals(newValue);
                mPreferenceManager.setUseLeakCanary(value);
                Activity activity = getActivity();
                if (activity != null) {
                    Utils.showSnackbar(activity, R.string.app_restart);
                }
                mSwitchLeakCanary.setChecked(value);
                return true;
        }
        return false;
    }
}

package com.moaz.focusstudiopro;

import android.content.Context;
import android.util.Base64;
import com.google.android.play.core.integrity.IntegrityManager;
import com.google.android.play.core.integrity.IntegrityManagerFactory;
import com.google.android.play.core.integrity.IntegrityTokenRequest;
import com.google.android.play.core.integrity.IntegrityTokenResponse;
import com.google.android.gms.tasks.Task;
import java.security.SecureRandom;

public class IntegrityHelper {
    private final IntegrityManager integrityManager;
    private final long cloudProjectNumber; // Set via BuildConfig or remote config

    public IntegrityHelper(Context context, long cloudProjectNumber) {
        this.integrityManager = IntegrityManagerFactory.create(context);
        this.cloudProjectNumber = cloudProjectNumber;
    }

    public Task<IntegrityTokenResponse> requestIntegrityToken() {
        byte[] nonceBytes = new byte[16];
        new SecureRandom().nextBytes(nonceBytes);
        String nonce = Base64.encodeToString(nonceBytes, Base64.URL_SAFE | Base64.NO_WRAP);

        IntegrityTokenRequest request = IntegrityTokenRequest.builder()
                .setCloudProjectNumber(cloudProjectNumber)
                .setNonce(nonce)
                .build();

        return integrityManager.requestIntegrityToken(request);
    }
}

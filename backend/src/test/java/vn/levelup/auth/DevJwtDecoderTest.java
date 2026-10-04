package vn.levelup.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;

class DevJwtDecoderTest {

    @Test
    void dev_tokens_are_decoded_locally_others_go_to_firebase() {
        AtomicReference<String> forwarded = new AtomicReference<>();
        JwtDecoder firebase = token -> {
            forwarded.set(token);
            return Jwt.withTokenValue(token).header("alg", "RS256").subject("firebase-uid").build();
        };
        JwtDecoder decoder = FirebaseJwtConfig.devOrFirebase(firebase);

        assertEquals("abc", decoder.decode("dev-abc").getSubject());
        assertEquals(null, forwarded.get());                       // token dev không gửi sang Firebase

        assertEquals("firebase-uid", decoder.decode("eyJ.real.token").getSubject());
        assertEquals("eyJ.real.token", forwarded.get());

        assertThrows(BadJwtException.class, () -> decoder.decode("dev-"));
    }

    @Test
    void malformed_non_dev_token_is_rejected_by_real_firebase_decoder() {
        JwtDecoder decoder = FirebaseJwtConfig.devOrFirebase(FirebaseJwtConfig.firebaseDecoder("levelup-pro"));
        assertThrows(org.springframework.security.oauth2.jwt.JwtException.class, () -> decoder.decode("not-a-jwt"));
    }
}

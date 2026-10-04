package vn.levelup.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import com.google.firebase.messaging.MessagingErrorCode;

class FcmPushSenderTest {

    @Test
    void invalid_tokens_are_removed_other_errors_are_not() {
        assertEquals(PushSender.Outcome.TOKEN_EXPIRED, FcmPushSender.outcomeFor(MessagingErrorCode.UNREGISTERED));
        assertEquals(PushSender.Outcome.TOKEN_EXPIRED, FcmPushSender.outcomeFor(MessagingErrorCode.INVALID_ARGUMENT));
        assertEquals(PushSender.Outcome.TOKEN_EXPIRED, FcmPushSender.outcomeFor(MessagingErrorCode.SENDER_ID_MISMATCH));
        assertEquals(PushSender.Outcome.FAILED, FcmPushSender.outcomeFor(MessagingErrorCode.UNAVAILABLE));
        assertEquals(PushSender.Outcome.FAILED, FcmPushSender.outcomeFor(MessagingErrorCode.QUOTA_EXCEEDED));
        assertEquals(PushSender.Outcome.FAILED, FcmPushSender.outcomeFor(null));
    }
}

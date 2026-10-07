package vn.levelup.training.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.shared.web.ApiErrors;
import vn.levelup.training.dto.CheckinRequest;
import vn.levelup.training.service.CheckinService;


class CheckinsControllerTest {

    private final CheckinService service = mock(CheckinService.class);
    private final CurrentUserService currentUser = mock(CurrentUserService.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new CheckinsController(service, currentUser))
        .setControllerAdvice(new ApiErrors()).build();

    @Test
    void post_accepts_optional_sleep_and_uses_authenticated_user() throws Exception {
        User user = mock(User.class);
        when(currentUser.require()).thenReturn(user);
        when(service.complete(user, new CheckinRequest("normal", null)))
            .thenReturn(new CheckinService.CheckinResponse("2026-10-03", "normal", null, false, null));
        mvc.perform(post("/checkins").contentType(MediaType.APPLICATION_JSON).content("{\"energy\":\"normal\"}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.localDate").value("2026-10-03"))
            .andExpect(jsonPath("$.energy").value("normal")).andExpect(jsonPath("$.adjusted").value(false))
            .andExpect(jsonPath("$.session").isEmpty());
        verify(currentUser).require();
        verify(service).complete(eq(user), eq(new CheckinRequest("normal", null)));
    }

    @ParameterizedTest
    @ValueSource(strings = {"{}", "{\"energy\":null}", "{\"energy\":\"\"}", "{\"energy\":\"invalid\"}",
        "{\"energy\":\"normal\",\"sleep\":\"\"}", "{\"energy\":\"normal\",\"sleep\":\"invalid\"}"})
    void invalid_values_use_common_validation_error(String body) throws Exception {
        mvc.perform(post("/checkins").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        verifyNoInteractions(currentUser, service);
    }

    @Test
    void onboarding_is_required() throws Exception {
        when(currentUser.require()).thenThrow(new ResponseStatusException(HttpStatus.NOT_FOUND, "ONBOARDING_REQUIRED"));
        mvc.perform(post("/checkins").contentType(MediaType.APPLICATION_JSON).content("{\"energy\":\"normal\"}"))
            .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
        verifyNoInteractions(service);
    }

    @Test
    void repeated_checkin_uses_common_conflict_code() throws Exception {
        User user = mock(User.class);
        when(currentUser.require()).thenReturn(user);
        when(service.complete(eq(user), any(CheckinRequest.class)))
            .thenThrow(new ResponseStatusException(HttpStatus.CONFLICT, "ALREADY_CHECKED_IN"));
        mvc.perform(post("/checkins").contentType(MediaType.APPLICATION_JSON).content("{\"energy\":\"normal\"}"))
            .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ALREADY_CHECKED_IN"));
    }
}

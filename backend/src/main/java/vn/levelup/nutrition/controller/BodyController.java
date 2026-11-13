package vn.levelup.nutrition.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.nutrition.dto.BodyView;
import vn.levelup.nutrition.service.BodyService;

@RestController
public class BodyController {

    private final BodyService body;
    private final CurrentUserService currentUser;

    public BodyController(BodyService body, CurrentUserService currentUser) {
        this.body = body;
        this.currentUser = currentUser;
    }

    /**
     * Chỉ số cơ thể cho màn Cơ thể: BMI, tỉ lệ mỡ (đo, tự chọn hoặc ước tính), BMR, TDEE và mục tiêu
     * dinh dưỡng đang áp dụng. Trường không tính được thì null.
     */
    @GetMapping("/me/body")
    public BodyView body() {
        return body.body(currentUser.require());
    }
}

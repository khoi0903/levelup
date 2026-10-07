package vn.levelup.nutrition.controller;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import vn.levelup.shared.web.ApiErrors;


/** Ảnh multipart vượt giới hạn của Spring (spring.servlet.multipart) → cùng mã lỗi với kiểm tra 2 MB. */
@RestControllerAdvice
public class UploadErrors {

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<ApiErrors.ApiError> tooLarge(MaxUploadSizeExceededException e) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
            .body(new ApiErrors.ApiError("IMAGE_TOO_LARGE", Map.of()));
    }
}

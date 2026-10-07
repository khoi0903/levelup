package vn.levelup.training.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.training.dto.MeasurementDtos;
import vn.levelup.training.service.MeasurementService;

@RestController
public class MeasurementsController {

    private final MeasurementService measurements;
    private final CurrentUserService currentUser;

    public MeasurementsController(MeasurementService measurements, CurrentUserService currentUser) {
        this.measurements = measurements;
        this.currentUser = currentUser;
    }

    /** Lưu số đo của một ngày (gộp với số đã nhập trong ngày đó). Có thể kèm huy hiệu giảm vòng eo. */
    @PostMapping("/measurements")
    public MeasurementDtos.SaveResponse save(@Valid @RequestBody MeasurementDtos.MeasurementRequest r) {
        return measurements.save(currentUser.require(), r);
    }

    /** Số đo trong N ngày gần nhất (mặc định 90, tối đa 730), cũ trước mới sau để vẽ biểu đồ. */
    @GetMapping("/measurements")
    public MeasurementDtos.ListResponse list(@RequestParam(name = "days", defaultValue = "90") int days) {
        return measurements.list(currentUser.require(), days);
    }
}

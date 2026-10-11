package vn.levelup.identity.controller;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.levelup.identity.dto.ProductConfig;
import vn.levelup.identity.dto.GrantProRequest;
import vn.levelup.identity.service.AdminService;
import vn.levelup.identity.service.ProductConfigService;

@RestController
@RequestMapping("/admin")
public class AdminController {
    private final AdminService admin;
    private final ProductConfigService configs;
    public AdminController(AdminService admin, ProductConfigService configs) { this.admin = admin; this.configs = configs; }
    @ModelAttribute
    public void authorize() { admin.requireAdmin(); }
    @GetMapping("/config")
    public ProductConfig get() { admin.requireAdmin(); return configs.get(); }
    @PutMapping("/config")
    public ProductConfig update(@Valid @RequestBody ProductConfig config) { return configs.update(admin.requireAdmin(), config); }
    @PostMapping("/grant-pro")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void grant(@Valid @RequestBody GrantProRequest request) { admin.grant(request); }
}

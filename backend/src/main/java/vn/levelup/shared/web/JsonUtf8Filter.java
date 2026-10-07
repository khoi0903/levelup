package vn.levelup.shared.web;

import java.io.IOException;

import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;

/**
 * Thêm "charset=UTF-8" vào mọi response JSON.
 * Gói http của Dart đọc body theo latin1 khi Content-Type không ghi charset,
 * làm tiếng Việt bị lỗi font.
 */
@Component
public class JsonUtf8Filter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        chain.doFilter(request, new HttpServletResponseWrapper(response) {
            @Override
            public void setContentType(String type) {
                super.setContentType(withCharset(type));
            }

            @Override
            public void setHeader(String name, String value) {
                super.setHeader(name, "Content-Type".equalsIgnoreCase(name) ? withCharset(value) : value);
            }
        });
    }

    static String withCharset(String type) {
        if (type != null && type.toLowerCase().startsWith("application/json") && !type.toLowerCase().contains("charset")) {
            return type + ";charset=UTF-8";
        }
        return type;
    }
}

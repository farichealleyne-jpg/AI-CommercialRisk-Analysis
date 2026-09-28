package com.policysquare.commercial.controller;

import com.policysquare.commercial.dto.AuthRequest;
import com.policysquare.commercial.dto.AuthResponse;
import com.policysquare.commercial.dto.SignupRequest;
import com.policysquare.commercial.model.AppUser;
import com.policysquare.commercial.repository.UserRepository;
import com.policysquare.commercial.security.CustomUserDetailsService;
import com.policysquare.commercial.security.JwtUtil;
import jakarta.validation.Valid;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@CrossOrigin(originPatterns = "*")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final CustomUserDetailsService userDetailsService;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @PostMapping("/signup")
    public ResponseEntity<?> registerUser(@Valid @RequestBody SignupRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            return badRequest("That username is already taken.");
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            return badRequest("That email address is already registered.");
        }

        if (userRepository.existsByMobileNumber(request.getMobileNumber())) {
            return badRequest("That mobile number is already registered.");
        }

        AppUser user = new AppUser();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setMobileNumber(request.getMobileNumber());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole("USER");

        userRepository.save(user);

        // Generate Token
        UserDetails userDetails = userDetailsService.loadUserByUsername(user.getUsername());
        String jwt = jwtUtil.generateToken(userDetails);

        return ResponseEntity.ok(new AuthResponse(jwt, user.getUsername(), user.getMobileNumber(), user.getEmail()));
    }

    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody AuthRequest request) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
            );
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", "Incorrect username or password."));
        }

        final UserDetails userDetails = userDetailsService.loadUserByUsername(request.getUsername());
        final String jwt = jwtUtil.generateToken(userDetails);
        
        AppUser user = userRepository.findByUsername(request.getUsername()).get();

        return ResponseEntity.ok(new AuthResponse(jwt, user.getUsername(), user.getMobileNumber(), user.getEmail()));
    }

    /** Errors must be real JSON: a bare string with a JSON content type
        fails to parse client-side and the reason is lost. */
    private ResponseEntity<Map<String, String>> badRequest(String message) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", message));
    }
}

package com.example.ecslab;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    private static final String FULL_NAME = "Alfred Nelly Dey";
    private static final String LAB_NAME = "AWS ECS Lab V2";

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("fullName", FULL_NAME);
        model.addAttribute("labName", LAB_NAME);
        return "index";
    }
}

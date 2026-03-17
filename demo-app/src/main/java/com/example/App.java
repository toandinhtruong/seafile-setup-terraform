package com.example;

import spark.Spark;

public class App {
    public static void main(String[] args) {
        Spark.port(8080);
        Spark.get("/", (req, res) -> "Hello from ECS + EC2 CI/CD!");
    }
}
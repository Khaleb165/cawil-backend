import 'package:dart_frog/dart_frog.dart';

const openapiSpec = r'''
{
  "openapi": "3.0.3",
  "info": {
    "title": "CaWil Backend API",
    "description": "Bus ticket booking backend. Dart Frog + PostgreSQL + JWT Auth",
    "version": "1.0.0",
    "contact": {
      "name": "CaWil Support",
      "email": "support@cawil.com"
    }
  },
  "servers": [
    {"url": "http://localhost:8080", "description": "Local development"},
    {"url": "https://cawil-backend.onrender.com", "description": "Production"}
  ],
  "components": {
    "securitySchemes": {
      "bearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      }
    },
    "schemas": {
      "User": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "uid": {"type": "string", "nullable": true},
          "email": {"type": "string", "format": "email"},
          "username": {"type": "string"},
          "avatar_url": {"type": "string"},
          "role": {"type": "string", "enum": ["user", "admin"]}
        }
      },
      "AuthResponse": {
        "type": "object",
        "properties": {
          "user": {"$ref": "#/components/schemas/User"},
          "access_token": {"type": "string"},
          "refresh_token": {"type": "string"}
        }
      },
      "Error": {
        "type": "object",
        "properties": {
          "error": {"type": "string"}
        }
      },
      "RegisterRequest": {
        "type": "object",
        "required": ["email", "password", "username"],
        "properties": {
          "email": {"type": "string", "format": "email"},
          "password": {"type": "string", "minLength": 6},
          "username": {"type": "string", "minLength": 1, "maxLength": 30}
        }
      },
      "LoginRequest": {
        "type": "object",
        "required": ["email", "password"],
        "properties": {
          "email": {"type": "string", "format": "email"},
          "password": {"type": "string"}
        }
      },
      "RefreshRequest": {
        "type": "object",
        "required": ["refresh_token"],
        "properties": {
          "refresh_token": {"type": "string"}
        }
      },
      "RefreshResponse": {
        "type": "object",
        "properties": {
          "access_token": {"type": "string"},
          "refresh_token": {"type": "string"}
        }
      },
      "UpdateProfileRequest": {
        "type": "object",
        "properties": {
          "username": {"type": "string"},
          "avatar_url": {"type": "string"}
        }
      },
      "Bus": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "bus_number": {"type": "string"},
          "plate_number": {"type": "string", "nullable": true},
          "total_seats": {"type": "integer"},
          "route_type": {"type": "string", "enum": ["long-distance", "local"]},
          "status": {"type": "string", "enum": ["active", "inactive"]}
        }
      },
      "CreateBusRequest": {
        "type": "object",
        "required": ["bus_number"],
        "properties": {
          "bus_number": {"type": "string"},
          "plate_number": {"type": "string"},
          "total_seats": {"type": "integer", "default": 32},
          "route_type": {"type": "string", "enum": ["long-distance", "local"], "default": "long-distance"}
        }
      },
      "UpdateBusRequest": {
        "type": "object",
        "properties": {
          "bus_number": {"type": "string"},
          "plate_number": {"type": "string"},
          "total_seats": {"type": "integer", "minimum": 18, "maximum": 64},
          "status": {"type": "string", "enum": ["active", "inactive"]}
        }
      },
      "Route": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "origin": {"type": "string"},
          "destination": {"type": "string"},
          "duration_hours": {"type": "number", "nullable": true},
          "base_price": {"type": "number", "nullable": true},
          "status": {"type": "string", "enum": ["active", "inactive"]}
        }
      },
      "CreateRouteRequest": {
        "type": "object",
        "required": ["origin", "destination"],
        "properties": {
          "origin": {"type": "string"},
          "destination": {"type": "string"},
          "duration_hours": {"type": "number", "minimum": 0.1, "maximum": 23.99},
          "base_price": {"type": "number", "minimum": 0}
        }
      },
      "UpdateRouteRequest": {
        "type": "object",
        "properties": {
          "origin": {"type": "string"},
          "destination": {"type": "string"},
          "duration_hours": {"type": "number", "minimum": 0.1, "maximum": 23.99},
          "base_price": {"type": "number", "minimum": 0},
          "status": {"type": "string", "enum": ["active", "inactive"]}
        }
      },
      "Schedule": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "bus_id": {"type": "integer"},
          "route_id": {"type": "integer"},
          "origin": {"type": "string"},
          "destination": {"type": "string"},
          "departure_time": {"type": "string", "format": "date-time"},
          "arrival_time": {"type": "string", "format": "date-time", "nullable": true},
          "report_time": {"type": "string", "format": "date-time", "nullable": true},
          "price": {"type": "number"},
          "seats_remaining": {"type": "integer"},
          "status": {"type": "string", "enum": ["active", "inactive", "departed"]}
        }
      },
      "ScheduleWithBus": {
        "type": "object",
        "properties": {
          "schedule": {"$ref": "#/components/schemas/Schedule"},
          "bus_info": {
            "type": "object",
            "properties": {
              "bus_number": {"type": "string"},
              "total_seats": {"type": "integer"}
            }
          }
        }
      },
      "CreateScheduleRequest": {
        "type": "object",
        "required": ["bus_id", "route_id", "departure_time"],
        "properties": {
          "bus_id": {"type": "integer"},
          "route_id": {"type": "integer"},
          "departure_time": {"type": "string", "format": "date-time"},
          "arrival_time": {"type": "string", "format": "date-time", "nullable": true},
          "price": {"type": "number", "minimum": 0, "description": "Optional override. Defaults to the route base_price."},
          "seats_remaining": {"type": "integer", "minimum": 0, "maximum": 64, "description": "Optional override. Defaults to the bus total_seats."}
        }
      },
      "UpdateScheduleRequest": {
        "type": "object",
        "required": ["seats_remaining"],
        "properties": {
          "seats_remaining": {"type": "integer", "minimum": 0, "maximum": 64}
        }
      },
      "Booking": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "user_id": {"type": "integer"},
          "schedule_id": {"type": "integer"},
          "seat_number": {"type": "string"},
          "passenger_name": {"type": "string"},
          "phone": {"type": "string"},
          "total_price": {"type": "number"},
          "booking_ref": {"type": "string"},
          "status": {"type": "string", "enum": ["confirmed", "cancelled", "no_show"]},
          "payment_status": {"type": "string", "enum": ["pending", "completed", "refunded"]}
        }
      },
      "BookingWithDetails": {
        "type": "object",
        "properties": {
          "booking": {"$ref": "#/components/schemas/Booking"},
          "passenger_email": {"type": "string", "nullable": true},
          "bus_number": {"type": "string", "nullable": true}
        }
      },
      "CreateBookingRequest": {
        "type": "object",
        "required": ["schedule_id", "seat_number", "passenger_name", "phone", "total_price"],
        "properties": {
          "schedule_id": {"type": "integer"},
          "seat_number": {"type": "string", "maxLength": 4},
          "passenger_name": {"type": "string", "maxLength": 100},
          "phone": {"type": "string", "maxLength": 20},
          "total_price": {"type": "number", "minimum": 0}
        }
      },
      "CreateBookingResponse": {
        "type": "object",
        "properties": {
          "id": {"type": "integer"},
          "booking_ref": {"type": "string"}
        }
      },
      "StatusResponse": {
        "type": "object",
        "properties": {
          "status": {"type": "string"}
        }
      },
      "HealthResponse": {
        "type": "object",
        "properties": {
          "status": {"type": "string"},
          "service": {"type": "string"},
          "version": {"type": "string"}
        }
      }
    },
    "responses": {
      "AuthSuccess": {
        "description": "Authentication successful",
        "content": {
          "application/json": {
            "schema": {"$ref": "#/components/schemas/AuthResponse"}
          }
        }
      },
      "Unauthorized": {
        "description": "Missing or invalid authentication",
        "content": {
          "application/json": {
            "schema": {"$ref": "#/components/schemas/Error"}
          }
        }
      },
      "Forbidden": {
        "description": "Insufficient permissions (admin required)",
        "content": {
          "application/json": {
            "schema": {"$ref": "#/components/schemas/Error"}
          }
        }
      },
      "NotFound": {
        "description": "Resource not found",
        "content": {
          "application/json": {
            "schema": {"$ref": "#/components/schemas/Error"}
          }
        }
      },
      "ValidationError": {
        "description": "Validation error",
        "content": {
          "application/json": {
            "schema": {"$ref": "#/components/schemas/Error"}
          }
        }
      }
    }
  },
  "paths": {
    "/": {
      "get": {
        "summary": "Health check",
        "operationId": "healthCheck",
        "tags": ["System"],
        "responses": {
          "200": {
            "description": "Service is healthy",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/HealthResponse"}
              }
            }
          }
        }
      }
    },
    "/auth/register": {
      "post": {
        "summary": "Register a new user account",
        "operationId": "register",
        "tags": ["Authentication"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/RegisterRequest"}
            }
          }
        },
        "responses": {
          "201": {"$ref": "#/components/responses/AuthSuccess"},
          "400": {"$ref": "#/components/responses/ValidationError"},
          "409": {
            "description": "Email already registered",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Error"}
              }
            }
          }
        }
      }
    },
    "/auth/login": {
      "post": {
        "summary": "Login with email and password",
        "operationId": "login",
        "tags": ["Authentication"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/LoginRequest"}
            }
          }
        },
        "responses": {
          "200": {"$ref": "#/components/responses/AuthSuccess"},
          "401": {
            "description": "Invalid email or password",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Error"}
              }
            }
          }
        }
      }
    },
    "/auth/refresh": {
      "post": {
        "summary": "Refresh access token using a refresh token",
        "operationId": "refreshToken",
        "tags": ["Authentication"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/RefreshRequest"}
            }
          }
        },
        "responses": {
          "200": {
            "description": "Tokens refreshed successfully",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/RefreshResponse"}
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"}
        }
      }
    },
    "/auth/me": {
      "get": {
        "summary": "Get current user profile",
        "operationId": "getProfile",
        "tags": ["Authentication"],
        "security": [{"bearerAuth": []}],
        "responses": {
          "200": {
            "description": "User profile",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "user": {"$ref": "#/components/schemas/User"}
                  }
                }
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"}
        }
      },
      "put": {
        "summary": "Update current user profile",
        "operationId": "updateProfile",
        "tags": ["Authentication"],
        "security": [{"bearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/UpdateProfileRequest"}
            }
          }
        },
        "responses": {
          "200": {
            "description": "Profile updated",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "user": {"$ref": "#/components/schemas/User"}
                  }
                }
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"}
        }
      }
    },
    "/admin/buses": {
      "get": {
        "summary": "List all buses (admin only)",
        "operationId": "listBuses",
        "tags": ["Admin - Buses"],
        "security": [{"bearerAuth": []}],
        "responses": {
          "200": {
            "description": "List of buses",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {"$ref": "#/components/schemas/Bus"}
                }
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      },
      "post": {
        "summary": "Create a new bus (admin only)",
        "operationId": "createBus",
        "tags": ["Admin - Buses"],
        "security": [{"bearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/CreateBusRequest"}
            }
          }
        },
        "responses": {
          "201": {
            "description": "Bus created",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Bus"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      }
    },
    "/admin/buses/{id}": {
      "put": {
        "summary": "Update a bus (admin only)",
        "operationId": "updateBus",
        "tags": ["Admin - Buses"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/UpdateBusRequest"}
            }
          }
        },
        "responses": {
          "200": {
            "description": "Bus updated",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Bus"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"},
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      },
      "delete": {
        "summary": "Delete a bus (admin only)",
        "operationId": "deleteBus",
        "tags": ["Admin - Buses"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "responses": {
          "200": {
            "description": "Bus deleted",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/StatusResponse"}
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"},
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      }
    },
    "/admin/route-defs": {
      "get": {
        "summary": "List all routes (admin only)",
        "operationId": "listRoutes",
        "tags": ["Admin - Routes"],
        "security": [{"bearerAuth": []}],
        "responses": {
          "200": {
            "description": "List of routes",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {"$ref": "#/components/schemas/Route"}
                }
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      },
      "post": {
        "summary": "Create a new route (admin only)",
        "operationId": "createRoute",
        "tags": ["Admin - Routes"],
        "security": [{"bearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/CreateRouteRequest"}
            }
          }
        },
        "responses": {
          "201": {
            "description": "Route created",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Route"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      }
    },
    "/admin/routes/{id}": {
      "put": {
        "summary": "Update a route (admin only)",
        "operationId": "updateRoute",
        "tags": ["Admin - Routes"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/UpdateRouteRequest"}
            }
          }
        },
        "responses": {
          "200": {
            "description": "Route updated",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Route"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"},
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      },
      "delete": {
        "summary": "Delete a route (admin only)",
        "operationId": "deleteRoute",
        "tags": ["Admin - Routes"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "responses": {
          "200": {
            "description": "Route deleted",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/StatusResponse"}
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"},
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      }
    },
    "/admin/schedules": {
      "get": {
        "summary": "List schedules (admin only)",
        "operationId": "adminListSchedules",
        "tags": ["Admin - Schedules"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "origin",
            "in": "query",
            "schema": {"type": "string"},
            "description": "Filter by origin city"
          },
          {
            "name": "destination",
            "in": "query",
            "schema": {"type": "string"},
            "description": "Filter by destination city"
          },
          {
            "name": "date",
            "in": "query",
            "schema": {"type": "string", "format": "date"},
            "description": "Filter by departure date (YYYY-MM-DD)"
          },
          {
            "name": "bus_id",
            "in": "query",
            "schema": {"type": "integer"},
            "description": "Filter by specific bus"
          }
        ],
        "responses": {
          "200": {
            "description": "List of schedules with bus info",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {"$ref": "#/components/schemas/ScheduleWithBus"}
                }
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      },
      "post": {
        "summary": "Create a schedule (admin only)",
        "operationId": "createSchedule",
        "tags": ["Admin - Schedules"],
        "security": [{"bearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/CreateScheduleRequest"}
            }
          }
        },
        "responses": {
          "201": {
            "description": "Schedule created",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/ScheduleWithBus"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"}
        }
      }
    },
    "/schedules": {
      "get": {
        "summary": "Search schedules by origin, destination, and/or date",
        "operationId": "searchSchedules",
        "tags": ["Schedules"],
        "parameters": [
          {
            "name": "origin",
            "in": "query",
            "schema": {"type": "string"},
            "description": "Filter by origin city"
          },
          {
            "name": "destination",
            "in": "query",
            "schema": {"type": "string"},
            "description": "Filter by destination city"
          },
          {
            "name": "date",
            "in": "query",
            "schema": {"type": "string", "format": "date"},
            "description": "Filter by departure date (YYYY-MM-DD)"
          },
          {
            "name": "bus_id",
            "in": "query",
            "schema": {"type": "integer"},
            "description": "Filter by specific bus"
          }
        ],
        "responses": {
          "200": {
            "description": "List of schedules with bus info",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {"$ref": "#/components/schemas/ScheduleWithBus"}
                }
              }
            }
          }
        }
      }
    },
    "/schedules/{id}": {
      "get": {
        "summary": "Get schedule details by ID",
        "operationId": "getSchedule",
        "tags": ["Schedules"],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "responses": {
          "200": {
            "description": "Schedule with bus info",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/ScheduleWithBus"}
              }
            }
          },
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      },
      "put": {
        "summary": "Update seats remaining for a schedule (admin only)",
        "operationId": "updateScheduleAvailability",
        "tags": ["Schedules"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/UpdateScheduleRequest"}
            }
          }
        },
        "responses": {
          "200": {
            "description": "Schedule updated",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/ScheduleWithBus"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {"$ref": "#/components/responses/Forbidden"},
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      }
    },
    "/bookings": {
      "post": {
        "summary": "Create a new booking (auth required)",
        "operationId": "createBooking",
        "tags": ["Bookings"],
        "security": [{"bearerAuth": []}],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {"$ref": "#/components/schemas/CreateBookingRequest"}
            }
          }
        },
        "responses": {
          "201": {
            "description": "Booking created",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/CreateBookingResponse"}
              }
            }
          },
          "400": {"$ref": "#/components/responses/ValidationError"},
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "409": {
            "description": "No seats available",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Error"}
              }
            }
          }
        }
      }
    },
    "/bookings/{id}": {
      "get": {
        "summary": "Get booking details (owner or admin only)",
        "operationId": "getBooking",
        "tags": ["Bookings"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "responses": {
          "200": {
            "description": "Booking details",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/BookingWithDetails"}
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {
            "description": "Only owner or admin can view this booking",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Error"}
              }
            }
          },
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      },
      "put": {
        "summary": "Cancel a booking (owner or admin only)",
        "operationId": "cancelBooking",
        "tags": ["Bookings"],
        "security": [{"bearerAuth": []}],
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "integer"}
          }
        ],
        "responses": {
          "200": {
            "description": "Booking cancelled",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/StatusResponse"}
              }
            }
          },
          "401": {"$ref": "#/components/responses/Unauthorized"},
          "403": {
            "description": "Only owner or admin can cancel this booking",
            "content": {
              "application/json": {
                "schema": {"$ref": "#/components/schemas/Error"}
              }
            }
          },
          "404": {"$ref": "#/components/responses/NotFound"}
        }
      }
    }
  },
  "tags": [
    {"name": "System", "description": "System health check"},
    {"name": "Authentication", "description": "Auth endpoints (register, login, refresh, profile)"},
    {"name": "Admin - Buses", "description": "Bus fleet management (admin only)"},
    {"name": "Admin - Routes", "description": "Route corridor management (admin only)"},
    {"name": "Admin - Schedules", "description": "Schedule creation and management (admin only)"},
    {"name": "Schedules", "description": "Schedule search and availability"},
    {"name": "Bookings", "description": "Booking creation and management"}
  ]
}
''';

Future<Response> onRequest(RequestContext context) async {
  return Response(
    body: openapiSpec,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  );
}

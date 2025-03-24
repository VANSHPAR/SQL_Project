CREATE TABLE sql_project.Account (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role ENUM('Admin', 'Customer') NOT NULL
);

CREATE TABLE sql_project.Customer (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT UNIQUE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    address TEXT,
    FOREIGN KEY (account_id) REFERENCES sql_project.Account(account_id) ON DELETE CASCADE
);

CREATE TABLE sql_project.Packages (
    package_id INT PRIMARY KEY AUTO_INCREMENT,
    package_name VARCHAR(100) NOT NULL,
    destination VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    duration INT NOT NULL,
    details TEXT
);

CREATE TABLE sql_project.Hotels (
    hotel_id INT PRIMARY KEY AUTO_INCREMENT,
    hotel_name VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    price_per_night DECIMAL(10,2) NOT NULL,
    amenities TEXT
);

CREATE TABLE sql_project.Bookings (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    package_id INT DEFAULT NULL,
    hotel_id INT DEFAULT NULL,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Confirmed', 'Pending', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES sql_project.Customer(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (package_id) REFERENCES sql_project.Packages(package_id),
    FOREIGN KEY (hotel_id) REFERENCES sql_project.Hotels(hotel_id)
);

CREATE TABLE sql_project.Payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_status ENUM('Completed', 'Failed', 'Pending') DEFAULT 'Pending',
    FOREIGN KEY (booking_id) REFERENCES sql_project.Bookings(booking_id) ON DELETE CASCADE
);

CREATE TABLE sql_project.Reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    package_id INT,
    hotel_id INT,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES sql_project.Customer(customer_id),
    FOREIGN KEY (package_id) REFERENCES sql_project.Packages(package_id),
    FOREIGN KEY (hotel_id) REFERENCES sql_project.Hotels(hotel_id)
);

-- Step 3: Stored Procedures
DELIMITER //

-- Procedure 1: Add a New Customer
CREATE PROCEDURE sql_project.AddCustomer(
    IN p_username VARCHAR(50), IN p_password_hash VARCHAR(255), IN p_email VARCHAR(100),
    IN p_name VARCHAR(100), IN p_phone VARCHAR(15), IN p_address TEXT
)
BEGIN
    DECLARE new_account_id INT;
    INSERT INTO sql_project.Account (username, password_hash, email, role) 
    VALUES (p_username, p_password_hash, p_email, 'Customer');
    
    SET new_account_id = LAST_INSERT_ID();
    
    INSERT INTO sql_project.Customer (account_id, name, phone, address) 
    VALUES (new_account_id, p_name, p_phone, p_address);
    
    SELECT 'Customer added successfully' AS message;
END //

-- Procedure 2: Book a Package
DELIMITER //
CREATE PROCEDURE sql_project.BookPackage(
    IN p_customer_id INT, IN p_package_id INT, IN p_hotel_id INT
)
BEGIN
    INSERT INTO sql_project.Bookings (customer_id, package_id, hotel_id, status) 
    VALUES (p_customer_id, p_package_id, p_hotel_id, 'Pending');
    
    SELECT 'Booking placed successfully' AS message;
END //

-- Procedure 3: Cancel a Booking
DELIMITER //
CREATE PROCEDURE sql_project.CancelBooking(IN p_booking_id INT)
BEGIN
    UPDATE sql_project.Bookings SET status = 'Cancelled' WHERE booking_id = p_booking_id;
    UPDATE sql_project.Payments SET payment_status = 'Failed' WHERE booking_id = p_booking_id AND payment_status = 'Pending';
    SELECT 'Booking cancelled successfully' AS message;
END //

-- Procedure 4:Make a Payment
DELIMITER //
CREATE PROCEDURE MakePayment(IN p_booking_id INT, IN p_amount DECIMAL(10,2))
BEGIN
    UPDATE Payments SET amount = p_amount, payment_status = 'Completed' WHERE booking_id = p_booking_id;
    UPDATE Bookings SET status = 'Confirmed' WHERE booking_id = p_booking_id;
    SELECT 'Payment successful, booking confirmed' AS message;
END //

DELIMITER ;

-- Step 4: Functions
DELIMITER //

-- Function 1: Get Customer Booking Count
CREATE FUNCTION sql_project.GetCustomerBookingCount(p_customer_id INT) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_bookings INT;
    SELECT COUNT(*) INTO total_bookings FROM sql_project.Bookings WHERE customer_id = p_customer_id;
    RETURN total_bookings;
END //

-- Function 2: Get Total Payment for a Booking
DELIMITER //
CREATE FUNCTION sql_project.GetTotalPayment(p_booking_id INT) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT SUM(amount) INTO total FROM sql_project.Payments WHERE booking_id = p_booking_id;
    RETURN COALESCE(total, 0);
END //

-- Function 3: Get Average Hotel Rating
DELIMITER //
CREATE FUNCTION sql_project.GetAvgHotelRating(p_hotel_id INT) RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    SELECT AVG(rating) INTO avg_rating FROM sql_project.Reviews WHERE hotel_id = p_hotel_id;
    RETURN COALESCE(avg_rating, 0);
END //

DELIMITER ;

-- Step 5: Triggers
DELIMITER //

-- Trigger 1: Automatically Create Payment Record After Booking
CREATE TRIGGER sql_project.After_Booking_Insert
AFTER INSERT ON sql_project.Bookings
FOR EACH ROW
BEGIN
    INSERT INTO sql_project.Payments (booking_id, amount, payment_status)
    VALUES (NEW.booking_id, 0, 'Pending');
END //

-- Trigger 2: Update Booking Status on Payment Completion
DELIMITER //
CREATE TRIGGER sql_project.After_Payment_Update
AFTER UPDATE ON sql_project.Payments
FOR EACH ROW
BEGIN
    IF NEW.payment_status = 'Completed' THEN
        UPDATE sql_project.Bookings SET status = 'Confirmed' WHERE booking_id = NEW.booking_id;
    END IF;
END //

-- Trigger 3: Prevent Deleting a Customer with Active Bookings
DELIMITER //
CREATE TRIGGER sql_project.Before_Customer_Delete
BEFORE DELETE ON sql_project.Customer
FOR EACH ROW
BEGIN
    DECLARE booking_count INT;
    SELECT COUNT(*) INTO booking_count FROM sql_project.Bookings WHERE customer_id = OLD.customer_id AND status = 'Confirmed';
    
    IF booking_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete customer with active bookings';
    END IF;
END //

DELIMITER ;

-- Step 6: Use Procedures for Data Insertion
CALL AddCustomer('alice_bob', 'alic123', 'alicebob@gmail.com', 'alice bob', '9895562345', 'Gujarat, India');
CALL AddCustomer('alice_smith', 'alic_pass', 'alicesmi@gmail.com', 'Alice Smith', '7856432144', 'Maharastra, India');

INSERT INTO Packages (package_name, destination, price, duration, details) VALUES 
('Beach Paradise', 'Goa', 50000, 5, 'Details of Beach paradise'),
('Pavagadh', 'Vadodara', 40000, 4, 'Includes trekking and adventure activities');

INSERT INTO Hotels (hotel_name, location, price_per_night, amenities) VALUES 
('Luxury Inn', 'Goa', 8000, 'WiFi, Pool, Breakfast'),
('Hotel Sayaji', 'Vadodara', 16000, 'Theatere, Gym, Spa');

-- Booking a Package using Procedure
CALL BookPackage(1, 1, 1);
CALL BookPackage(1, 2, 2);

-- Making Payments using Procedure
CALL MakePayment(1, 50000);
CALL MakePayment(2, 40000);

-- Adding Reviews
INSERT INTO Reviews (customer_id, hotel_id, rating, review_text) VALUES 
(1, 2, 5, 'Amazing experience!'), 
(2, 2, 4, 'Beautiful Mountains.');

-- Cancelling a Booking using Procedure
CALL CancelBooking(1);

-- Step 7: Test Queries
SELECT GetCustomerBookingCount(1) AS Total_Bookings;
SELECT GetTotalPayment(2) AS Total_Payment;
SELECT GetAvgHotelRating(2) AS Avg_Hotel_Rating;

SELECT * FROM Customer;
SELECT * FROM Bookings;
SELECT * FROM Payments;
SELECT * FROM Packages;
SELECT * FROM Reviews;
SELECT * FROM hotels;
SELECT * FROM Account;



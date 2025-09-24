/*String? validateEmail(String value) {
  if (value.isEmpty) {
    return 'Email is required';
  } else if (!value.contains('@')) {
    return 'Invalid email';
  }
  return null;
}*/

String? eventValidateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your email';
  }
  // Use regex for email validation
  if (!RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
      .hasMatch(value)) {
    return 'Please enter a valid email';
  }
  return null;
}

String? validateText(String? value, String message) {
  if (value == null || value.isEmpty) {
    return message;
  }
  /* // Use regex for email validation
  if (value.length < 3 || value.length > 10) {
    return 'Text length must be between 3 and 10 characters';
  }*/
  return null;
}

// Common function for password validation
String? eventValidatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your password';
  }
  // Check if the password length is at least 6 characters
  if (value.length < 6) {
    return 'Password must be at least 6 characters long';
  }
  // You can add additional password complexity rules here
  return null;
}

// Common function for password validation
String validateIndiaPhoneNumber(String value) {
  if (value.isEmpty) {
    return 'Please enter a phone number';
  }
  // Regular expression to validate phone number
  String pattern = r'^(?:[+0]9)?[0-9]{10}$';
  RegExp regExp = RegExp(pattern);
  if (!regExp.hasMatch(value)) {
    return 'Please enter a valid phone number';
  }
  return '';
}

String? validatePhoneNumber(String phoneNumber) {

  const int validDigits = 10;
  String numericPhoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

  int phoneNumberLength = numericPhoneNumber.length;
  if (phoneNumberLength == 0)
  {
    return 'Please enter your phone number';
  }
  if (phoneNumberLength != validDigits) {
    return
      'Phone number must be exactly 10 digits';
  }

  return null;
}


String? validateConfirmPassword(String? password, String? confirmPassword) {
  if (confirmPassword == null || confirmPassword.isEmpty) {
    return 'Please confirm your password';
  }
  if (password != confirmPassword) {
    return 'Passwords do not match';
  }
  return null;
}

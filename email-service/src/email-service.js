const nodemailer = require('nodemailer');
const { logger } = require('./logger');

// Create a nodemailer transporter
const createTransporter = () => {
  try {
    const transporter = nodemailer.createTransport({
      service: process.env.EMAIL_SERVICE,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD,
      },
      tls: {
        rejectUnauthorized: false, // Для локальной разработки
      }
    });
    
    return transporter;
  } catch (error) {
    logger.error(`Failed to create email transporter: ${error.message}`);
    throw error;
  }
};

// Send verification code email
const sendVerificationCode = async (email, code) => {
  try {
    const transporter = createTransporter();
    
    // Create email template
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Код подтверждения для Monkey Messenger',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #4A90E2;">Monkey Messenger - Двухфакторная аутентификация</h2>
          <p>Ваш код подтверждения:</p>
          <div style="font-size: 24px; font-weight: bold; background-color: #f1f1f1; padding: 15px; text-align: center; letter-spacing: 5px;">
            ${code}
          </div>
          <p style="margin-top: 20px;">Код действителен в течение 5 минут.</p>
          <p style="margin-top: 30px; font-size: 12px; color: #666;">
            Если вы не запрашивали код подтверждения, пожалуйста, проигнорируйте это сообщение.
          </p>
          <p style="font-size: 12px; color: #666;">
            © ${new Date().getFullYear()} Monkey Messenger. Все права защищены.
          </p>
        </div>
      `
    };
    
    // Send email
    const info = await transporter.sendMail(mailOptions);
    logger.info(`Email sent: ${info.messageId}`);
    
    return {
      success: true,
      messageId: info.messageId
    };
  } catch (error) {
    logger.error(`Error sending email: ${error.message}`);
    throw error;
  }
};

module.exports = {
  sendVerificationCode
}; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_debug_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support Section
            _buildContactSection(context),
            
            const SizedBox(height: 24),
            
            // FAQ Section
            _buildFAQSection(context),
            
            const SizedBox(height: 24),
            
            // App Information
            _buildAppInfoSection(context),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActionsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Liên Hệ Hỗ Trợ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📧 Email Hỗ Trợ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'hungbuit@gmail.com',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(context, 'hungbuit@gmail.com'),
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Sao chép email',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chúng tôi sẽ phản hồi trong vòng 24 giờ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendEmail(context),
                icon: const Icon(Icons.email, size: 20),
                label: const Text('Gửi Email Ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    final faqs = [
      {
        'question': 'Làm thế nào để tạo tài khoản?',
        'answer': 'Bạn có thể đăng nhập bằng tài khoản Google. Chỉ cần nhấn "Đăng nhập với Google" trên màn hình chính và cho phép ứng dụng truy cập thông tin cơ bản.'
      },
      {
        'question': 'Làm thế nào để thay đổi mục tiêu học tập hàng ngày?',
        'answer': 'Vào Profile → Cài đặt Thông báo → điều chỉnh "Mục tiêu hàng ngày". Bạn có thể chọn từ 5-50 từ mỗi ngày tùy theo khả năng.'
      },
      {
        'question': 'Tại sao tôi không nhận được thông báo?',
        'answer': 'Kiểm tra:\n• Cài đặt thông báo trong app đã bật chưa\n• Quyền thông báo của app trong Settings điện thoại\n• Do Not Disturb mode có đang bật không\n• Thời gian thông báo có phù hợp không'
      },
      {
        'question': 'Làm thế nào để ôn tập từ đã học?',
        'answer': 'Có nhiều cách:\n• Vào tab "Quiz" để làm bài kiểm tra\n• Sử dụng tính năng "Targeted Review" cho từ khó\n• Xem "Difficult Words" trong Profile\n• Thông báo tự động sẽ nhắc bạn ôn tập'
      },
      {
        'question': 'Streak (chuỗi ngày học) được tính như thế nào?',
        'answer': 'Streak tăng khi bạn học ít nhất 1 từ mỗi ngày. Nếu bỏ lỡ 1 ngày, streak sẽ reset về 0. Tips: học 2-3 từ mỗi sáng để duy trì streak dễ dàng!'
      },
      {
        'question': 'Dữ liệu học tập có được đồng bộ không?',
        'answer': 'Hiện tại dữ liệu được lưu cục bộ trên thiết bị. Chúng tôi đang phát triển tính năng đồng bộ cloud để bạn có thể truy cập từ nhiều thiết bị.'
      },
      {
        'question': 'App có hoạt động offline không?',
        'answer': 'Có! Tất cả từ vựng và bài học đều có thể sử dụng offline. Chỉ cần internet khi đăng nhập lần đầu và cập nhật nội dung mới.'
      },
      {
        'question': 'Làm thế nào để báo cáo lỗi hoặc đề xuất tính năng?',
        'answer': 'Gửi email cho chúng tôi tại hungbuit@gmail.com với:\n• Mô tả chi tiết vấn đề\n• Screenshots nếu có\n• Model điện thoại và phiên bản app\n• Các bước tái hiện lỗi'
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Câu Hỏi Thường Gặp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            ...faqs.map((faq) => _buildFAQItem(
              context,
              faq['question']!,
              faq['answer']!,
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Thông Tin App',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildInfoRow('📱 Phiên bản', '1.0.0'),
            _buildInfoRow('🏢 Nhà phát triển', 'Đông Sơn Software'),
            _buildInfoRow('📅 Cập nhật lần cuối', 'September 2025'),
            _buildInfoRow('⭐ Rating', '4.8/5 (Coming soon)'),
            _buildInfoRow('📊 Tổng từ vựng', '2,000+ từ vựng'),
            _buildInfoRow('🎯 Chủ đề', '15+ chủ đề'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Hành Động Nhanh',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    icon: Icons.refresh,
                    label: 'Reset Progress',
                    color: Colors.orange,
                    onTap: () => _showResetDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    icon: Icons.share,
                    label: 'Chia sẻ App',
                    color: Colors.green,
                    onTap: () => _shareApp(context),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    icon: Icons.bug_report,
                    label: 'Báo lỗi',
                    color: Colors.red,
                    onTap: () => _reportBug(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    icon: Icons.lightbulb,
                    label: 'Đề xuất',
                    color: Colors.blue,
                    onTap: () => _sendSuggestion(context),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Debug Tool  
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationDebugScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(Icons.build, color: Colors.purple, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔧 Debug Notifications',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sửa lỗi thông báo và kiểm tra hệ thống',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.purple, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Đã sao chép email vào clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendEmail(BuildContext context) async {
    // Copy email to clipboard and show instructions
    _copyToClipboard(context, 'hungbuit@gmail.com');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('📧 Gửi Email Hỗ Trợ'),
          content: const Text(
            'Email đã được sao chép vào clipboard!\n\n'
            'Vui lòng mở ứng dụng email và:\n'
            '1. Dán địa chỉ: hungbuit@gmail.com\n'
            '2. Tiêu đề: Đông Sơn GO App Support Request\n'
            '3. Mô tả vấn đề của bạn\n'
            '4. Thêm thông tin thiết bị nếu cần\n\n'
            'Chúng tôi sẽ phản hồi trong 24 giờ!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _copyToClipboard(context, 'hungbuit@gmail.com');
              },
              child: const Text('Sao chép lại'),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Reset Progress'),
          content: const Text(
            'Bạn có chắc muốn reset toàn bộ tiến trình học tập?\n\nHành động này không thể hoàn tác và sẽ xóa:\n• Tất cả từ đã học\n• Streak hiện tại\n• Quiz history\n• Achievement',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement reset functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng reset sẽ có trong phiên bản tiếp theo'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _shareApp(BuildContext context) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Tính năng chia sẻ sẽ có trong phiên bản tiếp theo'),
      ),
    );
  }

  void _reportBug(BuildContext context) {
    _sendEmail(context); // Reuse email functionality
  }

  void _sendSuggestion(BuildContext context) {
    _sendEmail(context); // Reuse email functionality
  }
}

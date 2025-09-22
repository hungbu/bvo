import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính Sách Bảo Mật'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context),
            
            const SizedBox(height: 24),
            
            // Privacy Policy Content
            _buildPrivacyPolicyContent(context),
            
            const SizedBox(height: 24),
            
            // Terms of Service
            _buildTermsOfService(context),
            
            const SizedBox(height: 24),
            
            // Contact Information
            _buildContactInfo(context),
            
            const SizedBox(height: 32),
            
            // Last Updated
            _buildLastUpdated(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🛡️ Cam Kết Bảo Mật',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Chúng tôi cam kết bảo vệ quyền riêng tư và thông tin cá nhân của bạn',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyContent(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Chính Sách Bảo Mật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            _buildPolicySection(
              '1. Thông Tin Chúng Tôi Thu Thập',
              [
                '• Thông tin tài khoản Google (tên, email, avatar) khi đăng nhập',
                '• Dữ liệu học tập (từ đã học, điểm quiz, streak, progress)',
                '• Cài đặt ứng dụng (thông báo, mục tiêu hàng ngày)',
                '• Thông tin thiết bị cơ bản (model, OS version) để tối ưu hiệu suất',
              ],
            ),
            
            _buildPolicySection(
              '2. Cách Chúng Tôi Sử Dụng Thông Tin',
              [
                '• Cung cấp trải nghiệm học tập cá nhân hóa',
                '• Theo dõi tiến trình và tạo báo cáo học tập',
                '• Gửi thông báo nhắc nhở phù hợp',
                '• Cải thiện tính năng và hiệu suất ứng dụng',
                '• Hỗ trợ kỹ thuật khi có yêu cầu',
              ],
            ),
            
            _buildPolicySection(
              '3. Lưu Trữ và Bảo Mật Dữ Liệu',
              [
                '• Dữ liệu được lưu cục bộ trên thiết bị của bạn',
                '• Không chia sẻ thông tin cá nhân với bên thứ ba',
                '• Sử dụng mã hóa để bảo vệ dữ liệu nhạy cảm',
                '• Tuân thủ các tiêu chuẩn bảo mật quốc tế',
                '• Backup định kỳ để đảm bảo an toàn dữ liệu',
              ],
            ),
            
            _buildPolicySection(
              '4. Quyền Của Người Dùng',
              [
                '• Truy cập và xem thông tin cá nhân đã lưu',
                '• Chỉnh sửa hoặc cập nhật thông tin',
                '• Xóa tài khoản và toàn bộ dữ liệu',
                '• Tắt/bật thông báo và tính năng theo ý muốn',
                '• Xuất dữ liệu học tập (tính năng sắp có)',
              ],
            ),
            
            _buildPolicySection(
              '5. Cookies và Tracking',
              [
                '• Không sử dụng cookies hoặc tracking tools',
                '• Không thu thập dữ liệu duyệt web',
                '• Chỉ sử dụng analytics cơ bản để cải thiện app',
                '• Hoàn toàn offline sau khi đăng nhập',
              ],
            ),
            
            _buildPolicySection(
              '6. Chia Sẻ Thông Tin',
              [
                '• KHÔNG bán thông tin cá nhân',
                '• KHÔNG chia sẻ với bên thứ ba vì mục đích thương mại',
                '• Chỉ chia sẻ khi có yêu cầu pháp lý',
                '• Thông báo trước khi có thay đổi chính sách',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsOfService(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📜 Điều Khoản Sử Dụng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            _buildPolicySection(
              '1. Chấp Nhận Điều Khoản',
              [
                '• Bằng việc sử dụng app, bạn đồng ý với các điều khoản',
                '• Cập nhật điều khoản sẽ được thông báo qua app',
                '• Tiếp tục sử dụng = chấp nhận điều khoản mới',
              ],
            ),
            
            _buildPolicySection(
              '2. Sử Dụng Hợp Lệ',
              [
                '• Sử dụng app cho mục đích học tập cá nhân',
                '• Không hack, reverse engineer, hoặc phá hoại',
                '• Không spam hoặc lạm dụng tính năng',
                '• Tuân thủ pháp luật địa phương',
              ],
            ),
            
            _buildPolicySection(
              '3. Nội Dung và Bản Quyền',
              [
                '• Từ vựng và bài học thuộc bản quyền Đông Sơn Software',
                '• Cho phép sử dụng cá nhân, không thương mại',
                '• Không sao chép, phân phối lại nội dung',
                '• Báo cáo vi phạm bản quyền qua email hỗ trợ',
              ],
            ),
            
            _buildPolicySection(
              '4. Giới Hạn Trách Nhiệm',
              [
                '• App cung cấp "như hiện tại", không bảo đảm 100% hoàn hảo',
                '• Không chịu trách nhiệm về gián đoạn dịch vụ',
                '• Người dùng tự chịu trách nhiệm về việc sử dụng',
                '• Không bảo đảm kết quả học tập cụ thể',
              ],
            ),
            
            _buildPolicySection(
              '5. Thay Đổi và Chấm Dứt',
              [
                '• Có quyền cập nhật app và tính năng',
                '• Có thể ngừng cung cấp dịch vụ với thông báo trước',
                '• Người dùng có thể dừng sử dụng bất cứ lúc nào',
                '• Dữ liệu sẽ được xóa khi ngừng sử dụng',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📞 Liên Hệ và Khiếu Nại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    'Nếu bạn có thắc mắc về chính sách bảo mật hoặc muốn khiếu nại:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
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
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Sao chép email',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✅ Phản hồi trong 24-48 giờ\n'
                    '✅ Hỗ trợ tiếng Việt và English\n'
                    '✅ Giải quyết khiếu nại miễn phí',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Text(
            '📅 Cập nhật lần cuối: 22 tháng 9, 2025',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Phiên bản chính sách: 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '💡 Chính sách có thể được cập nhật để tuân thủ luật pháp và cải thiện dịch vụ. '
            'Thay đổi quan trọng sẽ được thông báo qua email hoặc trong app.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              point,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          )).toList(),
        ],
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
}

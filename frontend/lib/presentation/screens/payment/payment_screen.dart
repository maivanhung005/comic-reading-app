import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/comic_entity.dart';
import '../../viewmodels/payment_viewmodel.dart';

class PaymentScreen extends StatefulWidget {
  final ComicEntity comic; final ChapterEntity chapter; final int userId;
  const PaymentScreen({super.key, required this.comic, required this.chapter, required this.userId});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'MOCK';
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentViewModel>();
    return Scaffold(appBar: AppBar(title: const Text('Mở khóa chương VIP')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: ListTile(title: Text(widget.comic.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Chương ${widget.chapter.chapterNumber}: ${widget.chapter.title}'), trailing: Text('${widget.chapter.price} đ'))),
      const SizedBox(height: 20), const Text('Chọn hình thức (bản demo)', style: TextStyle(fontWeight: FontWeight.bold)),
      RadioListTile<String>(value: 'MOCK', groupValue: _method, onChanged: (value) => setState(() => _method = value!), title: const Text('Thanh toán mô phỏng')),
      RadioListTile<String>(value: 'MOMO', groupValue: _method, onChanged: (value) => setState(() => _method = value!), title: const Text('MoMo sandbox (chưa tích hợp thật)')),
      RadioListTile<String>(value: 'ZALOPAY', groupValue: _method, onChanged: (value) => setState(() => _method = value!), title: const Text('ZaloPay sandbox (chưa tích hợp thật)')),
      if (vm.error != null) Text(vm.error!, style: const TextStyle(color: Colors.red)),
      const Spacer(),
      FilledButton.icon(onPressed: vm.isProcessing ? null : () async {
        final ok = await context.read<PaymentViewModel>().pay(userId: widget.userId, chapterId: widget.chapter.id, amount: widget.chapter.price, method: _method);
        if (!context.mounted) return;
        if (ok) { Navigator.pop(context, true); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<PaymentViewModel>().error ?? 'Thanh toán thất bại'))); }
      }, icon: vm.isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_open), label: Text(vm.isProcessing ? 'Đang xử lý...' : 'Xác nhận thanh toán')),
      const SizedBox(height: 8), const Text('Thanh toán hiện chỉ ghi giao dịch mô phỏng trên máy chủ, không thu tiền thật.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ])));
  }
}

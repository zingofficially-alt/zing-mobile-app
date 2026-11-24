import 'package:flutter_test/flutter_test.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';

void main() {
  group('Product', () {
    test('inStock needs both availability and quantity', () {
      expect(Product(id: 'a', name: 'A', price: 1, quantity: 3).inStock, isTrue);
      expect(Product(id: 'a', name: 'A', price: 1, quantity: 0).inStock, isFalse);
      expect(
        Product(id: 'a', name: 'A', price: 1, quantity: 3, isAvailable: false).inStock,
        isFalse,
      );
    });

    test('fromRow keeps stock, availability and discount', () {
      final p = Product.fromRow({
        'id': 'p1',
        'name': 'Rice',
        'price': 250,
        'quantity': 12,
        'is_available': true,
        'discount': 10,
      });
      expect(p.id, 'p1');
      expect(p.price, 250.0);
      expect(p.quantity, 12);
      expect(p.discount, 10.0);
      expect(p.inStock, isTrue);
    });

    test('effectivePrice applies the discount percentage', () {
      expect(Product(id: 'a', name: 'A', price: 200, discount: 25).effectivePrice, 150);
      expect(Product(id: 'a', name: 'A', price: 200).effectivePrice, 200);
    });

    test('lowStock flags the last few units only', () {
      expect(Product(id: 'a', name: 'A', price: 1, quantity: 5).lowStock, isTrue);
      expect(Product(id: 'a', name: 'A', price: 1, quantity: 6).lowStock, isFalse);
      expect(Product(id: 'a', name: 'A', price: 1, quantity: 0).lowStock, isFalse);
    });
  });

  group('OrderStatus', () {
    test('only the next step or a cancellation is allowed', () {
      expect(OrderStatus.canMove('Pending', 'Processed'), isTrue);
      expect(OrderStatus.canMove('Pending', 'Shipped'), isFalse);
      expect(OrderStatus.canMove('Shipped', 'Cancelled'), isTrue);
      expect(OrderStatus.canMove('Delivered', 'Cancelled'), isFalse);
      expect(OrderStatus.canMove('Cancelled', 'Pending'), isFalse);
    });

    test('wording depends on pickup or delivery', () {
      expect(OrderStatus.customerLabel('Shipped', 'Pickup'), 'Ready for pickup');
      expect(OrderStatus.customerLabel('Shipped', 'Home Delivery'), 'Out for delivery');
    });
  });

  group('Orders.fromRow', () {
    final row = {
      'id': 'o1',
      'user_id': 'u1',
      'store_id': 's1',
      'total_price': 280,
      'delivery_fee': 80,
      'delivery_address': ' 12 Palm Rd ',
      'status': 'Processed',
      'delivery_method': 'Home Delivery',
      'placed_at': '2026-11-20T10:00:00Z',
      'cancelled_by': null,
      'store': {'name': 'Shop B'},
      'order_items': [
        {'product_id': 'p1', 'name': 'Widget', 'price': 90, 'quantity': 2},
        {'product_id': 'p2', 'name': 'Gadget', 'price': 40, 'quantity': 1},
      ],
      'order_status_history': [
        {'status': 'Processed', 'changed_at': '2026-11-20T11:00:00Z'},
        {'status': 'Pending', 'changed_at': '2026-11-20T10:00:00Z'},
      ],
    };

    test('reads fee, address, store name and sorted history', () {
      final o = Orders.fromRow(row);
      expect(o.deliveryFee, 80);
      expect(o.deliveryAddress, '12 Palm Rd');
      expect(o.storeName, 'Shop B');
      expect(o.isHomeDelivery, isTrue);
      expect(o.statusHistory.map((h) => h.status), ['Pending', 'Processed']);
      expect(o.reachedAt('Processed'), isNotNull);
      expect(o.reachedAt('Shipped'), isNull);
    });

    test('counts units, not rows', () {
      final o = Orders.fromRow(row);
      expect(o.itemCount, 3);
      expect(o.lines.map((l) => '${l.name}x${l.quantity}'), ['Widgetx2', 'Gadgetx1']);
    });

    test('customers can cancel only while pending', () {
      expect(Orders.fromRow({...row, 'status': 'Pending'}).canCustomerCancel, isTrue);
      expect(Orders.fromRow(row).canCustomerCancel, isFalse);
    });
  });

  group('OpeningHours', () {
    test('standard hours: open Monday morning, closed on Sunday', () {
      final h = OpeningHours.standard();
      expect(h.statusAt(DateTime(2026, 11, 23, 10)).isOpen, isTrue); // Monday
      expect(h.statusAt(DateTime(2026, 11, 23, 20)).isOpen, isFalse);
      expect(h.statusAt(DateTime(2026, 11, 22, 12)).isOpen, isFalse); // Sunday
    });

    test('round-trips through a map', () {
      final copy = OpeningHours.fromMap(OpeningHours.standard().toMap())!;
      expect(copy.days.length, 7);
      expect(copy.days[6].closed, isTrue);
      expect(copy.days[0].open, 9 * 60);
    });

    test('temporarily closed overrides the hours', () {
      final s = Store(
        phoneNumber: '',
        name: 'S',
        description: '',
        category: '',
        imageUrl: '',
        products: const [],
        owner: Owner(id: 'o', name: '', email: '', phone: '', profileImageUrl: ''),
        location: const GeoPoint(0, 0),
        openingHours: OpeningHours.standard(),
        temporarilyClosed: true,
      );
      expect(s.openStatus(DateTime(2026, 11, 23, 10))!.isOpen, isFalse);
    });
  });

  group('CustomUser', () {
    CustomUser user({String role = 'User', List<Payment>? payments}) => CustomUser(
          id: 'u',
          name: 'N',
          email: 'e',
          phoneNumber: 'p',
          role: role,
          payments: payments,
        );

    test('role helpers', () {
      expect(user(role: 'Admin').isAdmin, isTrue);
      expect(user(role: 'Owner').isOwner, isTrue);
      expect(user().isAdmin, isFalse);
    });

    test('subscription days left count from the latest payment', () {
      Payment paid(DateTime at) => Payment(
            storeId: 's',
            paymentId: 'x',
            amount: 1,
            currency: 'LKR',
            items: '',
            paymentStatus: 'Completed',
            paymentDate: Timestamp.fromDate(at),
          );
      final now = DateTime(2026, 11, 24);
      expect(user().subscriptionDaysLeft(now), isNull);
      expect(
          user(payments: [paid(DateTime(2026, 11, 14))]).subscriptionDaysLeft(now), 20);
      expect(
          user(payments: [paid(DateTime(2026, 9, 1)), paid(DateTime(2026, 11, 14))])
              .subscriptionDaysLeft(now),
          20);
      expect(user(payments: [paid(DateTime(2026, 9, 1))]).subscriptionDaysLeft(now), 0);
    });
  });

  group('CartItem', () {
    test('totalPrice multiplies price by quantity', () {
      expect(CartItem(id: 'c', name: 'C', price: 99.5, quantity: 3).totalPrice, 298.5);
    });
  });
}

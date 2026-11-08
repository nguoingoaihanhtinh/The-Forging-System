import { describe, expect, it, vi } from 'vitest';
import { RedemptionService } from '../../src/modules/armory/redemption.service';
import type { MarksWalletPort, PointsPort } from '../../src/modules/points/points.service';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { RedemptionRepository } from '../../src/modules/armory/redemption.repository';
import { Role } from '../../src/shared/roles';

const order = {
  id: 'redemption-1',
  memberId: 'member-1',
  rewardId: 'reward-1',
  pickupBranchId: 'branch-1',
  redemptionCode: 'GIFT-001',
  marksCost: 120,
  status: 'PENDING_PICKUP',
  requestedAt: new Date('2026-11-01T00:00:00Z'),
  reason: null,
  decidedBy: null,
  decidedAt: null,
  deliveryEvidenceUrl: null,
};

describe('GFT-03 redemption approval', () => {
  const repo = {
    memberForOrder: vi.fn(),
    lockMember: vi.fn(),
    lockOrder: vi.fn(),
    transitionToReadyPickup: vi.fn(),
    transition: vi.fn(),
    restoreStock: vi.fn(),
  };
  const audit = { record: vi.fn() };
  const points = { award: vi.fn() };
  const service = new RedemptionService(
    repo as unknown as RedemptionRepository,
    audit as unknown as AuditService,
    points as unknown as MarksWalletPort & PointsPort,
  );
  const reception = { userId: 'reception-1', roles: [Role.RECEPTIONIST], branchId: 'branch-1' };

  it('moves a branch-owned pending redemption to READY_PICKUP without touching points or stock', async () => {
    vi.resetAllMocks();
    repo.memberForOrder.mockResolvedValue(order.memberId);
    repo.lockMember.mockResolvedValue({ id: order.memberId });
    repo.lockOrder.mockResolvedValue(order);
    const ready = { ...order, status: 'READY_PICKUP', decidedBy: reception.userId };
    repo.transitionToReadyPickup.mockResolvedValue(ready);

    await expect(service.approvePickup(order.id, { reason: 'Đã đối chiếu kho' }, reception)).resolves.toEqual({
      redemption: ready,
      duplicate: false,
    });
    expect(repo.transitionToReadyPickup).toHaveBeenCalledWith(order.id, reception.userId, 'Đã đối chiếu kho');
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'REDEMPTION_READY_PICKUP' }));
  });

  it('is idempotent for an already ready redemption and rejects another branch', async () => {
    vi.resetAllMocks();
    const ready = { ...order, status: 'READY_PICKUP' };
    repo.memberForOrder.mockResolvedValue(order.memberId);
    repo.lockMember.mockResolvedValue({ id: order.memberId });
    repo.lockOrder.mockResolvedValue(ready);
    await expect(service.approvePickup(order.id, {}, reception)).resolves.toEqual({ redemption: ready, duplicate: true });
    expect(repo.transitionToReadyPickup).not.toHaveBeenCalled();

    repo.lockOrder.mockResolvedValue(order);
    await expect(service.approvePickup(order.id, {}, { ...reception, branchId: 'branch-2' })).rejects.toMatchObject({
      code: 'PICKUP_BRANCH_MISMATCH',
    });
  });

  it('delivers only a ready redemption and debits its exact Marks snapshot', async () => {
    vi.resetAllMocks();
    const ready = { ...order, status: 'READY_PICKUP' };
    const delivered = { ...ready, status: 'DELIVERED' };
    repo.memberForOrder.mockResolvedValue(order.memberId);
    repo.lockMember.mockResolvedValue({ id: order.memberId });
    repo.lockOrder.mockResolvedValue(ready);
    repo.transition.mockResolvedValue(delivered);

    await expect(service.confirmDelivery(order.id, { reason: 'Đã giao tại quầy' }, reception)).resolves.toEqual({
      redemption: delivered,
      duplicate: false,
    });
    expect(points.award).toHaveBeenCalledWith(expect.objectContaining({
      memberId: order.memberId,
      marks: -order.marksCost,
      redemptionId: order.id,
    }));
    expect(repo.transition).toHaveBeenCalledWith(order.id, 'DELIVERED', reception.userId, 'Đã giao tại quầy', null);
  });

  it('does not debit a redemption that was not approved for pickup', async () => {
    vi.resetAllMocks();
    repo.memberForOrder.mockResolvedValue(order.memberId);
    repo.lockMember.mockResolvedValue({ id: order.memberId });
    repo.lockOrder.mockResolvedValue(order);
    await expect(service.confirmDelivery(order.id, {}, reception)).rejects.toMatchObject({
      code: 'REDEMPTION_NOT_READY',
    });
    expect(points.award).not.toHaveBeenCalled();
  });

  it('rejects an open redemption, releasing its Marks hold and restoring one reserved stock item', async () => {
    vi.resetAllMocks();
    const ready = { ...order, status: 'READY_PICKUP' };
    const rejected = { ...ready, status: 'REJECTED' };
    repo.memberForOrder.mockResolvedValue(order.memberId);
    repo.lockMember.mockResolvedValue({ id: order.memberId });
    repo.lockOrder.mockResolvedValue(ready);
    repo.transition.mockResolvedValue(rejected);

    await expect(service.rejectPickup(order.id, { reason: 'Hết hàng tại quầy' }, reception)).resolves.toEqual({
      redemption: rejected,
      duplicate: false,
    });
    expect(points.award).not.toHaveBeenCalled();
    expect(repo.restoreStock).toHaveBeenCalledWith(ready, reception.userId, 'Hết hàng tại quầy');
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'REDEMPTION_REJECTED' }));
  });
});

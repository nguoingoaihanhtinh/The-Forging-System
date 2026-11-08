import { describe, expect, it, vi } from 'vitest';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { InventoryRepository } from '../../src/modules/armory/inventory.repository';
import { InventoryService } from '../../src/modules/armory/inventory.service';

function build() {
  const repo = {
    lockReward: vi.fn(),
    setStock: vi.fn(),
    insert: vi.fn(),
    history: vi.fn(),
    searchRewards: vi.fn(),
  };
  const audit = { record: vi.fn() };
  const service = new InventoryService(
    repo as unknown as InventoryRepository,
    audit as unknown as AuditService,
  );
  return { repo, audit, service };
}

describe('GFT-02 inventory service', () => {
  it('delegates the reception reward search to the repository', async () => {
    const { repo, service } = build();
    const page = { items: [{ id: 'reward-1', sku: 'GLOVES', name: 'Găng tập', stock: 4, isActive: true }], total: 1 };
    repo.searchRewards.mockResolvedValue(page);

    await expect(service.rewards({ q: 'găng' }, 20, 40)).resolves.toBe(page);
    expect(repo.searchRewards).toHaveBeenCalledWith({ q: 'găng' }, 20, 40);
  });

  it('adds stock, writes the movement and audits an inbound adjustment', async () => {
    const { repo, audit, service } = build();
    repo.lockReward.mockResolvedValue({ id: 'reward-1', name: 'Găng tập', stock: 10 });
    const movement = { id: 'movement-1', movementType: 'IN', quantity: 5 };
    repo.insert.mockResolvedValue(movement);

    await expect(
      service.adjust({ rewardId: 'reward-1', movementType: 'IN', quantity: 5, reason: 'Nhập hàng' }, 'staff-1'),
    ).resolves.toEqual({ movement, stockBefore: 10, stockAfter: 15 });
    expect(repo.setStock).toHaveBeenCalledWith('reward-1', 15);
    expect(repo.insert).toHaveBeenCalledWith({
      rewardId: 'reward-1',
      movementType: 'IN',
      quantity: 5,
      reason: 'Nhập hàng',
      actorId: 'staff-1',
    });
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({
      actorId: 'staff-1',
      action: 'INVENTORY_IN',
      entityType: 'REWARD',
      entityId: 'reward-1',
      before: { stock: 10 },
      after: { stock: 15, movement },
    }));
  });

  it('refuses to take more stock than available and writes nothing', async () => {
    const { repo, audit, service } = build();
    repo.lockReward.mockResolvedValue({ id: 'reward-1', name: 'Găng tập', stock: 3 });

    await expect(
      service.adjust({ rewardId: 'reward-1', movementType: 'OUT', quantity: 4, reason: 'Xuất kho' }, 'staff-1'),
    ).rejects.toMatchObject({ code: 'INSUFFICIENT_STOCK' });
    expect(repo.setStock).not.toHaveBeenCalled();
    expect(repo.insert).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('reports a missing reward before touching stock', async () => {
    const { repo, service } = build();
    repo.lockReward.mockResolvedValue(null);

    await expect(
      service.adjust({ rewardId: 'missing', movementType: 'IN', quantity: 1, reason: 'Nhập hàng' }, 'staff-1'),
    ).rejects.toMatchObject({ code: 'NOT_FOUND' });
    expect(repo.setStock).not.toHaveBeenCalled();
  });
});

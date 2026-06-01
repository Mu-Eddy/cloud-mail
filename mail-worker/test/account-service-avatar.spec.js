import { beforeEach, describe, expect, it, vi } from 'vitest';

const { normalize, update, set, where, updateRun, prepare, bind, first, alterRun } = vi.hoisted(() => ({
	normalize: vi.fn(),
	update: vi.fn(),
	set: vi.fn(),
	where: vi.fn(),
	updateRun: vi.fn(),
	prepare: vi.fn(),
	bind: vi.fn(),
	first: vi.fn(),
	alterRun: vi.fn()
}));

vi.mock('../src/entity/orm.js', () => ({
	default: () => ({
		update
	})
}));

vi.mock('../src/service/account-avatar-service.js', () => ({
	default: {
		normalize
	}
}));

describe('account service avatar updates', () => {
	let accountService;
	const c = { env: { db: { prepare } } };

	beforeEach(async () => {
		vi.clearAllMocks();
		updateRun.mockResolvedValue();
		alterRun.mockResolvedValue();
		first.mockResolvedValue({ name: 'avatar_type' });
		bind.mockReturnValue({ first });
		prepare.mockImplementation((sql) => {
			if (sql.startsWith('ALTER TABLE')) {
				return { run: alterRun };
			}
			return { bind };
		});
		where.mockReturnValue({ run: updateRun });
		set.mockReturnValue({ where });
		update.mockReturnValue({ set });
		normalize.mockResolvedValue({ avatarType: 'logo', avatar: '' });
		accountService = (await import('../src/service/account-service.js')).default;
	});

	it('normalizes and stores avatar settings for the account owner', async () => {
		const params = { accountId: 1, avatarType: 'logo', avatar: 'old' };
		const service = {
			...accountService,
			selectById: vi.fn().mockResolvedValue({ accountId: 1, userId: 7 })
		};

		const result = await service.setAvatar(c, params, 7);

		expect(normalize).toHaveBeenCalledWith(c, params);
		expect(set).toHaveBeenCalledWith({ avatarType: 'logo', avatar: '' });
		expect(updateRun).toHaveBeenCalledOnce();
		expect(result).toEqual({ avatarType: 'logo', avatar: '' });
	});

	it('rejects avatar updates for accounts owned by another user', async () => {
		const service = {
			...accountService,
			selectById: vi.fn().mockResolvedValue({ accountId: 1, userId: 8 })
		};

		await expect(service.setAvatar(c, {
			accountId: 1,
			avatarType: 'logo'
		}, 7)).rejects.toMatchObject({ name: 'BizError' });

		expect(normalize).not.toHaveBeenCalled();
		expect(updateRun).not.toHaveBeenCalled();
	});

	it('adds missing avatar columns before updating avatar settings', async () => {
		first.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
		const service = {
			...accountService,
			selectById: vi.fn().mockResolvedValue({ accountId: 1, userId: 7 })
		};

		await service.setAvatar(c, {
			accountId: 1,
			avatarType: 'logo'
		}, 7);

		expect(bind).toHaveBeenCalledWith('avatar_type');
		expect(bind).toHaveBeenCalledWith('avatar');
		expect(prepare).toHaveBeenCalledWith(`ALTER TABLE account ADD COLUMN avatar_type TEXT NOT NULL DEFAULT 'initial';`);
		expect(prepare).toHaveBeenCalledWith(`ALTER TABLE account ADD COLUMN avatar TEXT NOT NULL DEFAULT '';`);
		expect(alterRun).toHaveBeenCalledTimes(2);
	});

	it('normalizes and stores avatar settings for a managed user account', async () => {
		const params = { accountId: 2, avatarType: 'logo', avatar: 'old' };
		const service = {
			...accountService,
			selectById: vi.fn().mockResolvedValue({ accountId: 2, userId: 8 })
		};

		const result = await service.setManagedAvatar(c, params);

		expect(service.selectById).toHaveBeenCalledWith(c, 2);
		expect(normalize).toHaveBeenCalledWith(c, params);
		expect(set).toHaveBeenCalledWith({ avatarType: 'logo', avatar: '' });
		expect(updateRun).toHaveBeenCalledOnce();
		expect(result).toEqual({ avatarType: 'logo', avatar: '' });
	});

	it('rejects managed avatar updates when the account does not exist', async () => {
		const service = {
			...accountService,
			selectById: vi.fn().mockResolvedValue(null)
		};

		await expect(service.setManagedAvatar(c, {
			accountId: 2,
			avatarType: 'logo'
		})).rejects.toMatchObject({ name: 'BizError' });

		expect(normalize).not.toHaveBeenCalled();
		expect(updateRun).not.toHaveBeenCalled();
	});
});

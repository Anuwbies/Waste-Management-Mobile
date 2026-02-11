const rewardMap: Record<string, number> = {
  plastic: 5,
  metal: 8,
  glass: 6,
  paper: 4,
  organic: 3,
  "e-waste": 15,
  ewaste: 15, // Alternative spelling support
};

export const calculateRewardPoints = (wasteType: string): number => {
  const normalized = wasteType.toLowerCase().trim();
  return rewardMap[normalized] ?? 2;
};

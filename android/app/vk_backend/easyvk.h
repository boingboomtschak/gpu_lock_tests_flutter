#include <vulkan/vulkan.h>
#include <vector>

namespace easyvk {

	const uint32_t push_constant_size_bytes = 20;

	class Device;
	class Buffer;

	class Instance {
		public:
			Instance(bool = false);
			std::vector<easyvk::Device> devices();
			void teardown();
		private:
			bool enableValidationLayers;
			VkInstance instance;
			VkDebugReportCallbackEXT debugReportCallback;
	};

	class Device {
		public:
			Device(Instance &_instance, VkPhysicalDevice _physicalDevice);
			VkDevice device;
			VkPhysicalDeviceProperties properties;
			uint32_t selectMemory(VkBuffer buffer, VkMemoryPropertyFlags flags);
			VkQueue computeQueue();
			VkCommandBuffer computeCommandBuffer;
			void teardown();
		private:
			Instance &instance;
			VkPhysicalDevice physicalDevice;
			VkCommandPool computePool;
			uint32_t computeFamilyId = uint32_t(-1);
	};

	class Buffer {
		public:
			Buffer(Device &device, uint32_t size);
			VkBuffer buffer;

			void store(size_t i, uint32_t value) {
				*(data + i) = value;
			}

			uint32_t load(size_t i) {
				return *(data + i);
			}
			void clear() {
				for (uint32_t i = 0; i < size; i++)
					store(i, 0);
			}

			void teardown();
		private:
			easyvk::Device &device;
			VkDeviceMemory memory;
			uint32_t size;
            uint32_t* data;
	};

	class Program {
		public:
			Program(Device &_device, const char* filepath, std::vector<easyvk::Buffer> &buffers);
			Program(Device &_device, std::vector<uint32_t> spvCode, std::vector<easyvk::Buffer> &buffers);
			void initialize();
			void prepare();
			void run();
			void setWorkgroups(uint32_t _numWorkgroups);
			void setWorkgroupSize(uint32_t _workgroupSize);
			void teardown();
		private:
			std::vector<easyvk::Buffer> &buffers;
			VkShaderModule shaderModule;
			easyvk::Device &device;
			VkDescriptorSetLayout descriptorSetLayout;
			VkDescriptorPool descriptorPool;
			VkDescriptorSet descriptorSet;
			std::vector<VkWriteDescriptorSet> writeDescriptorSets;
			std::vector<VkDescriptorBufferInfo> bufferInfos;
			VkPipelineLayout pipelineLayout;
			VkPipeline pipeline;
			uint32_t numWorkgroups;
			uint32_t workgroupSize;
	};

	const char* vkDeviceType(VkPhysicalDeviceType type);
}

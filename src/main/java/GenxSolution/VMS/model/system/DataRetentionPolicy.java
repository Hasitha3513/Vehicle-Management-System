package GenxSolution.VMS.model.reports;

import lombok.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class DataRetentionPolicy {
    private UUID policyId;
    private String tableName;
    private Integer retentionMonths;
    private Boolean archiveBeforeDelete;
    private Boolean isActive;
    private OffsetDateTime createdAt;
}
